"""Parse explicit numeric tokens without interpreting colloquial shorthand.

This module never rewrites a whole user message: brand/model names are untouched.
Only canonical Chinese unit notation is accepted (三百五 stays ambiguous).
"""
from decimal import Decimal
import re

DIGITS = "零一二三四五六七八九"
CHINESE_DIGITS = "零〇一二两三四五六七八九"
NUMBER_PATTERN = rf"(?:[0-9０-９]+(?:[.．][0-9０-９]+)?|[{CHINESE_DIGITS}十百千万]+(?:点[{CHINESE_DIGITS}]+)?)"
FULLWIDTH_NUMBERS = str.maketrans("０１２３４５６７８９．", "0123456789.")


def _format_section(value: int) -> str:
    """Canonical spelling for a value below 10,000, including internal zeros."""
    result = ""
    zero_pending = False
    for divisor, suffix in ((1000, "千"), (100, "百"), (10, "十"), (1, "")):
        digit, value = divmod(value, divisor)
        if digit:
            if zero_pending:
                result += "零"
            result += DIGITS[digit] + suffix
            zero_pending = False
        elif result and value:
            zero_pending = True
    return result or "零"


def _format_integer(value: int) -> str:
    high, low = divmod(value, 10000)
    if not high:
        result = _format_section(low)
    else:
        result = _format_section(high) + "万"
        if low:
            result += ("零" if low < 1000 else "") + _format_section(low)
    return result[1:] if result.startswith("一十") else result


def _chinese_integer(text: str) -> int:
    # Normalize spelling variants, not magnitudes or missing units.
    text = text.replace("〇", "零").replace("两", "二")
    total = section = digit = 0
    for char in text:
        if char in DIGITS:
            digit = DIGITS.index(char)
        elif char == "万":
            total += (section + digit) * 10000
            section = digit = 0
        else:
            unit = {"十": 10, "百": 100, "千": 1000}[char]
            section += (digit or 1) * unit
            digit = 0
    value = total + section + digit
    if value >= 100_000_000:
        raise ValueError("Chinese numeral outside supported range")
    canonical = _format_integer(value)
    comparable = text[1:] if text.startswith("一十") else text
    if comparable != canonical:
        raise ValueError("Ambiguous or non-canonical Chinese numeral")
    return value


def parse_number(token: str) -> float:
    """Convert a complete numeric token, rejecting malformed/ambiguous notation."""
    token = token.translate(FULLWIDTH_NUMBERS)
    if re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", token):
        return float(Decimal(token))
    if not re.fullmatch(NUMBER_PATTERN, token):
        raise ValueError("Unsupported numeric token")
    integer, separator, fraction = token.partition("点")
    value = Decimal(_chinese_integer(integer))
    if separator:
        fraction = fraction.replace("〇", "零").replace("两", "二")
        digits = "".join(str(DIGITS.index(char)) for char in fraction)
        value += Decimal("0." + digits)
    return float(value)
