// send-monthly-report
// --------------------
// Scheduled (pg_cron) function. Emails each opted-in user their 30-day RepGate
// health summary via Azure Communication Services. Requires x-cron-secret.

import { invoke, requireCron } from "../_shared/common.ts";
import { runReportSweep } from "../_shared/reports.ts";

Deno.serve((req) => invoke("send-monthly-report", req, async (request) => {
  requireCron(request);
  const result = await runReportSweep("monthly");
  if (!result.configured) {
    console.warn("[send-monthly-report] Azure ACS email not configured; nothing sent.");
  }
  return result;
}));
