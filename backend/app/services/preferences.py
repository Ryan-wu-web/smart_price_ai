"""SQLite is authoritative; never switch databases silently on failure."""
from contextlib import closing
import logging
from pathlib import Path
import sqlite3

from app.config import settings
from app.models.preferences import PreferenceProfile, PreferenceUpdate
from app.services.sessions import SessionError

logger = logging.getLogger(__name__)

class PreferenceStore:
    def __init__(self, path=None):
        self.path = Path(path or settings.preference_sqlite_path)

    def _connect(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.path, timeout=2)
        try:
            connection.execute("CREATE TABLE IF NOT EXISTS local_preferences (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
            connection.commit()
            return connection
        except Exception:
            connection.close()
            raise

    @staticmethod
    def _read(connection):
        row = connection.execute("SELECT payload FROM local_preferences WHERE id=1").fetchone()
        return PreferenceProfile.model_validate_json(row[0]) if row else PreferenceProfile()

    def read(self):
        try:
            with closing(self._connect()) as connection:
                return self._read(connection)
        except Exception as exc:
            logger.warning("preference_read_failed type=%s", type(exc).__name__)
            raise SessionError("长期偏好暂时无法读取；可不应用偏好继续购物，原数据未删除。", "PREFERENCES_UNAVAILABLE", 503) from None

    def replace(self, request: PreferenceUpdate):
        try:
            with closing(self._connect()) as connection, connection:
                connection.execute("BEGIN IMMEDIATE")
                current = self._read(connection)
                if current.revision != request.expected_revision:
                    raise SessionError("长期偏好已更新，请刷新后重新确认。", "PREFERENCE_REVISION_CONFLICT", 409)
                result = PreferenceProfile(revision=current.revision + 1, items=request.items)
                connection.execute("INSERT INTO local_preferences(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", (result.model_dump_json(),))
                return result
        except SessionError:
            raise
        except Exception as exc:
            logger.warning("preference_write_failed type=%s", type(exc).__name__)
            raise SessionError("长期偏好未能保存，请刷新确认状态后重试。", "PREFERENCES_UNAVAILABLE", 503) from None
