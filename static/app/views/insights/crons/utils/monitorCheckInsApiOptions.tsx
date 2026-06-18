import {apiOptions} from 'sentry/utils/api/apiOptions';
import type {CheckIn} from 'sentry/views/insights/crons/types';

interface MonitorChecksParameters {
  monitorIdOrSlug: string;
  orgSlug: string;
  projectSlug: string;
  cursor?: string;
  environment?: string[];
  expand?: 'groups';
  limit?: number;
  query?: string;
  sort?: string;
  asc?: string;
  // Only allow explicitly forwarded pagination/filter params.
}

export function monitorCheckInsApiOptions({
  orgSlug,
  projectSlug,
  monitorIdOrSlug,
  cursor,
  limit,
  environment,
  expand,
  query,
  sort,
  asc,
}: MonitorChecksParameters) {
  return apiOptions.as<CheckIn[]>()(
    '/projects/$organizationIdOrSlug/$projectIdOrSlug/monitors/$monitorIdOrSlug/checkins/',
    {
      path: {
        organizationIdOrSlug: orgSlug,
        projectIdOrSlug: projectSlug,
        monitorIdOrSlug,
      },
      query: {per_page: limit, cursor, environment, expand, query, sort, asc},
      staleTime: 0,
    }
  );
}
