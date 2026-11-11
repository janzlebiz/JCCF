"""
==============================================================================
JCCF Module M13: FastAPI Route Contracts & Pydantic v2 Schemas
Subsystem: Interactive Personalization Engine
Target: Python 3.11+ / FastAPI / Pydantic v2
Status: Pre-Implementation Specification (Ready for Phase 1 Execution)
==============================================================================
"""

from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, HttpUrl, field_validator


# ==============================================================================
# 1. INTAKE & SESSION SCHEMAS
# ==============================================================================

class SessionCreateResponse(BaseModel):
    """Returned upon initializing a new guest quiz session."""
    session_token: str = Field(description="Raw high-entropy session token stored on client")
    template_id: UUID
    current_step: str
    expires_at: datetime


class SessionUpdateRequest(BaseModel):
    """Payload for debounced step auto-save."""
    step_id: str = Field(min_length=1, max_length=50)
    answers: Dict[str, Any] = Field(description="Key-value answer pairs for this step")

    @field_validator("answers")
    @classmethod
    def sanitize_strings(cls, v: Dict[str, Any]) -> Dict[str, Any]:
        """Strip dangerous HTML characters from all string inputs."""
        sanitized = {}
        for key, val in v.items():
            if isinstance(val, str):
                # Basic HTML escaping
                sanitized[key] = (
                    val.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace('"', "&quot;")
                )
            else:
                sanitized[key] = val
        return sanitized


class SessionUpdateResponse(BaseModel):
    status: str = "success"
    next_step: Optional[str]
    updated_at: datetime


# ==============================================================================
# 2. ASSET UPLOAD SCHEMAS
# ==============================================================================

class AssetUploadResponse(BaseModel):
    asset_id: UUID
    slot_id: str = Field(description="Target slot: p1, p2, p3, p4, p5, p6")
    width: int
    height: int
    estimated_dpi: int
    content_type: str


# ==============================================================================
# 3. PREVIEW SCHEMAS
# ==============================================================================

class PreviewGenerateRequest(BaseModel):
    palette_id: str = Field(pattern="^(sage|terracotta|navy|sand|rose)$")
    icon_id: str = Field(default="paw_classic")


class PreviewGenerateResponse(BaseModel):
    preview_url: HttpUrl
    render_time_ms: int
    pet_name: str
    palette_id: str


# ==============================================================================
# 4. CHECKOUT & WEBHOOK SCHEMAS
# ==============================================================================

class CheckoutInitiateRequest(BaseModel):
    return_url: HttpUrl


class CheckoutInitiateResponse(BaseModel):
    checkout_url: HttpUrl
    session_id: UUID


class LemonSqueezyWebhookPayload(BaseModel):
    """Subset of Lemon Squeezy order webhook payload."""
    meta: Dict[str, Any]
    data: Dict[str, Any]


# ==============================================================================
# 5. DELIVERY SCHEMAS
# ==============================================================================

class DeliveryInfoResponse(BaseModel):
    order_id: UUID
    pet_name: str
    page_count: int = 24
    download_url: HttpUrl
    expires_at: datetime
    downloads_remaining: int

