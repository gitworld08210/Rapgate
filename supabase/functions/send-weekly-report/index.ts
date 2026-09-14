// send-weekly-report
// -------------------
// Scheduled (pg_cron) function. Emails each opted-in user their 7-day RepGate
// health summary via Azure Communication Services. Requires x-cron-secret.

import { invoke, requireCron } from "../_shared/common.ts";
import { runReportSweep } from "../_shared/reports.ts";

Deno.serve((req) => invoke("send-weekly-report", req, async (request) => {
  requireCron(request);
  const result = await runReportSweep("weekly");
  if (!result.configured) {
    console.warn("[send-weekly-report] Azure ACS email not configured; nothing sent.");
  }
  return result;
}));
