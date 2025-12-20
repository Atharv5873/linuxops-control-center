# Alerting Engine — LOCC

The alerting engine evaluates monitoring data emitted by the LOCC monitoring agent and detects abnormal system conditions based on configurable thresholds.

It is responsible for:
- Threshold-based alert detection
- Alert state tracking to prevent noise
- Dispatching alerts to external channels

This module does not perform remediation.
