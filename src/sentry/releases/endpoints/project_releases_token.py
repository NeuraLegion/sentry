import hmac
from hashlib import sha256
from uuid import uuid1

from django.urls import reverse
from rest_framework.request import Request
from rest_framework.response import Response

from sentry.api.api_publish_status import ApiPublishStatus
from sentry.api.base import cell_silo_endpoint
from sentry.api.bases.project import ProjectEndpoint, StrictProjectPermission
from sentry.api.permissions import DisallowImpersonatedTokenCreation
from sentry.models.options.project_option import ProjectOption
from sentry.types.cell import get_local_locality


def _get_webhook_url(project, plugin_id, token):
    return get_local_locality().to_url(
        reverse(
            "sentry-release-hook",
            kwargs={
                "plugin_id": plugin_id,
                "project_id": project.id,
                "signature": _get_signature(project.id, plugin_id, token),
            },
        )
    )


def _get_signature(project_id, plugin_id, token):
    return hmac.new(
        key=token.encode("utf-8"),
        msg=(f"{plugin_id}-{project_id}").encode(),
        digestmod=sha256,
    ).hexdigest()


@cell_silo_endpoint
class ProjectReleasesTokenEndpoint(ProjectEndpoint):
    publish_status = {
        "GET": ApiPublishStatus.PRIVATE,
        "POST": ApiPublishStatus.PRIVATE,
    }
    permission_classes = (StrictProjectPermission, DisallowImpersonatedTokenCreation)

    def _regenerate_token(self, project):
        token = uuid1().hex
        ProjectOption.objects.set_value(project, "sentry:release-token", token)
        return token

    def _has_project_write_access(self, request: Request, project) -> bool:
        return bool(request.access and request.access.has_project_access(project, "write"))

    def get(self, request: Request, project) -> Response:
        return Response(status=404)

    def post(self, request: Request, project) -> Response:
        if not self._has_project_write_access(request, project):
            return Response(status=404)

        self._regenerate_token(project)

        return Response(status=204)
