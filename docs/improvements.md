Diagnostic System Improvements

## Fixed Issues

1. Fixed the `create_phase1_report.sh` script to correctly extract Kubernetes version from cluster reports
2. Updated the Flux issues detection to use case-insensitive pattern matching and handle grep exit codes
3. Fixed pod issues detection to handle cases where no problematic pods are found
4. Updated the `run_diagnostics.sh` script to continue execution even if individual checks fail
5. Fixed syntax errors in the report generation for code blocks

## Added Features

1. Created a comprehensive system diagnostic report in `docs/system-diagnostic-report.md`
2. Added a detailed README.md for the diagnostics directory
3. Improved error handling throughout all scripts
4. Enhanced the report organization with a structured directory hierarchy
5. Added support for lightweight mode in resource-constrained environments

## Next Steps

1. Implement fixes for the Helm repository issues identified in the diagnostics
2. Troubleshoot the Supabase deployment issues
3. Optimize resource usage for the Minikube environment
4. Consider implementing automated periodic diagnostics
5. Create more detailed troubleshooting guides based on common issues identified
