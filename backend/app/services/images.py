from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from io import BytesIO
import shutil
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import get_settings


ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}

@dataclass(frozen=True)
class StoredImage:
    original_path: str
    thumb_256_path: str
    thumb_768_path: str
    mime_type: str
    width: int
    height: int
    file_size_bytes: int
    checksum_sha256: str
    captured_at: Optional[datetime]


def storage_root() -> Path:
    root = Path(get_settings().plantbuddy_storage_path).expanduser()
    return root.resolve()


def resolve_storage_path(relative_path: str) -> Path:
    root = storage_root()
    full_path = (root / relative_path).resolve()
    if root not in full_path.parents and full_path != root:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid storage path")
    return full_path


def delete_plant_images(plant_id: str) -> None:
    plant_path = resolve_storage_path(str(Path("plants") / plant_id))
    root = storage_root()
    if plant_path == root or root not in plant_path.parents:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid plant storage path")
    if plant_path.exists():
        shutil.rmtree(plant_path)


def delete_stored_image(relative_path: Optional[str]) -> None:
    if not relative_path:
        return
    path = resolve_storage_path(relative_path)
    if path.exists() and path.is_file():
        path.unlink()


def delete_photo_files(photo) -> None:
    delete_stored_image(photo.original_path)
    delete_stored_image(photo.thumb_256_path)
    delete_stored_image(photo.thumb_768_path)


async def store_plant_image(plant_id: str, photo_id: str, upload: UploadFile) -> StoredImage:
    if upload.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Upload must be a JPEG, PNG, or WebP image",
        )

    raw = await upload.read()
    if not raw:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded image is empty")
    max_upload_bytes = get_settings().max_upload_mb * 1024 * 1024
    if len(raw) > max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded image is too large",
        )

    try:
        image = Image.open(BytesIO(raw))
        captured_at = _extract_captured_at(image)
        image = ImageOps.exif_transpose(image)
        image.load()
    except UnidentifiedImageError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image file") from exc

    normalized = _to_rgb(image)
    checksum = sha256(raw).hexdigest()

    plant_dir = Path("plants") / plant_id
    original_rel = plant_dir / "originals" / f"{photo_id}.jpg"
    thumb_256_rel = plant_dir / "thumbs" / f"{photo_id}_256.jpg"
    thumb_768_rel = plant_dir / "thumbs" / f"{photo_id}_768.jpg"

    original_path = resolve_storage_path(str(original_rel))
    thumb_256_path = resolve_storage_path(str(thumb_256_rel))
    thumb_768_path = resolve_storage_path(str(thumb_768_rel))

    try:
        original_path.parent.mkdir(parents=True, exist_ok=True)
        thumb_256_path.parent.mkdir(parents=True, exist_ok=True)
        thumb_768_path.parent.mkdir(parents=True, exist_ok=True)

        _save_jpeg(normalized, original_path, quality=90)
        _save_thumbnail(normalized, thumb_256_path, max_size=256)
        _save_thumbnail(normalized, thumb_768_path, max_size=768)
    except OSError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image storage path is not writable",
        ) from exc

    return StoredImage(
        original_path=str(original_rel).replace("\\", "/"),
        thumb_256_path=str(thumb_256_rel).replace("\\", "/"),
        thumb_768_path=str(thumb_768_rel).replace("\\", "/"),
        mime_type="image/jpeg",
        width=normalized.width,
        height=normalized.height,
        file_size_bytes=original_path.stat().st_size,
        checksum_sha256=checksum,
        captured_at=captured_at,
    )


async def store_plant_icon(plant_id: str, upload: UploadFile) -> str:
    if upload.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Icon must be a JPEG, PNG, or WebP image",
        )

    raw = await upload.read()
    if not raw:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded icon is empty")
    max_upload_bytes = get_settings().max_upload_mb * 1024 * 1024
    if len(raw) > max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Uploaded icon is too large",
        )

    try:
        image = Image.open(BytesIO(raw))
        image = ImageOps.exif_transpose(image)
        image.load()
    except UnidentifiedImageError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid icon file") from exc

    normalized = _to_rgb(image)
    icon_rel = Path("plants") / plant_id / "icon" / "icon.jpg"
    icon_path = resolve_storage_path(str(icon_rel))
    try:
        icon_path.parent.mkdir(parents=True, exist_ok=True)
        icon = ImageOps.fit(normalized, (192, 192), method=Image.Resampling.LANCZOS)
        _save_jpeg(icon, icon_path, quality=84)
    except OSError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Icon storage path is not writable",
        ) from exc

    return str(icon_rel).replace("\\", "/")


def _to_rgb(image: Image.Image) -> Image.Image:
    if image.mode in ("RGBA", "LA"):
        background = Image.new("RGB", image.size, (255, 255, 255))
        alpha = image.getchannel("A")
        background.paste(image.convert("RGBA"), mask=alpha)
        return background
    if image.mode != "RGB":
        return image.convert("RGB")
    return image


def _extract_captured_at(image: Image.Image) -> Optional[datetime]:
    try:
        exif = image.getexif()
    except (AttributeError, OSError, ValueError):
        return None
    if not exif:
        return None
    for tag in (36867, 36868, 306):
        value = exif.get(tag)
        if not value:
            continue
        if isinstance(value, bytes):
            value = value.decode(errors="ignore")
        try:
            return datetime.strptime(str(value).strip(), "%Y:%m:%d %H:%M:%S").replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _save_jpeg(image: Image.Image, path: Path, quality: int) -> None:
    image.save(path, format="JPEG", quality=quality, optimize=True, progressive=True)


def _save_thumbnail(image: Image.Image, path: Path, max_size: int) -> None:
    thumbnail = image.copy()
    thumbnail.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
    _save_jpeg(thumbnail, path, quality=82)
