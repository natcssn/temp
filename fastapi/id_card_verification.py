"""ID card OCR and college-name matching helpers."""
import json
import os
import re
from typing import Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

_RAPID_OCR_ENGINE = None

COLLEGE_ALIASES = {
    "SSN/SNU": [
        "ssn",
        "snu",
        "sri sivasubramaniya nadar college of engineering",
        "ssn college of engineering",
        "shiv nadar university",
        "shiv nadar",
    ],
    "VITC": ["vit", "vit chennai", "vitc"],
    "REC": ["rajalakshmi engineering college", "rec", "rit"],
}


def _normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def _extract_text_with_rapidocr(image_path: str) -> Optional[str]:
    global _RAPID_OCR_ENGINE
    try:
        from rapidocr_onnxruntime import RapidOCR
    except Exception:
        return None

    try:
        if _RAPID_OCR_ENGINE is None:
            _RAPID_OCR_ENGINE = RapidOCR()

        result, _ = _RAPID_OCR_ENGINE(image_path)
        if not result:
            return ""

        pieces = []
        for row in result:
            if isinstance(row, (list, tuple)) and len(row) >= 2 and isinstance(row[1], str):
                pieces.append(row[1])
        return " ".join(pieces).strip()
    except Exception:
        return None


def _extract_generated_text(payload):
    if isinstance(payload, str):
        return payload
    if isinstance(payload, list):
        parts = []
        for item in payload:
            value = _extract_generated_text(item)
            if value:
                parts.append(value)
        return " ".join(parts).strip()
    if isinstance(payload, dict):
        for key in ("generated_text", "text", "label"):
            if key in payload and isinstance(payload[key], str):
                return payload[key]
    return ""


def _extract_text_with_huggingface(image_path: str) -> Optional[str]:
    token = os.getenv("HF_TOKEN", "").strip()
    if not token:
        return None

    model = os.getenv("HF_OCR_MODEL", "microsoft/trocr-base-printed")
    url = f"https://api-inference.huggingface.co/models/{model}"

    try:
        with open(image_path, "rb") as handle:
            body = handle.read()

        req = Request(
            url,
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/octet-stream",
            },
        )
        with urlopen(req, timeout=25) as response:
            raw = response.read().decode("utf-8", errors="ignore")
        payload = json.loads(raw)
        return _extract_generated_text(payload)
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError):
        return None


def _matches_college(extracted_text: str, college_name: str) -> bool:
    normalized_text = _normalize_text(extracted_text)
    aliases = COLLEGE_ALIASES.get(college_name, [college_name])

    for alias in aliases:
        normalized_alias = _normalize_text(alias)
        if normalized_alias and normalized_alias in normalized_text:
            return True
    return False


def verify_college_from_id_card(image_path: str, college_name: str) -> Tuple[bool, str, str, str]:
    providers = [
        ("rapidocr_onnxruntime", _extract_text_with_rapidocr),
        ("huggingface_inference", _extract_text_with_huggingface),
    ]

    extracted_text = ""
    used_provider = "none"

    for provider_name, provider_fn in providers:
        output = provider_fn(image_path)
        if output is None:
            continue
        extracted_text = output.strip()
        used_provider = provider_name
        break

    if not extracted_text:
        return False, "idcard and college chosen doesnt match", "", used_provider

    if _matches_college(extracted_text, college_name):
        return True, "verified", extracted_text, used_provider

    return False, "idcard and college chosen doesnt match", extracted_text, used_provider