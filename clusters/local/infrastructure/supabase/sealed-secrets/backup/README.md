# Backup Directory

This directory contains backups of previous versions of the SealedSecrets files. These are kept for historical reference only and should not be used for deployment.

## Contents

- **before-field-correction/**: Contains SealedSecrets before field names were corrected to match the expected field names in the Supabase deployment. These files had naming inconsistencies that caused deployment issues.

## Notes

If you need to revert to a previous version, make sure to:

1. Verify field names match those expected by the Supabase Helm chart
2. Ensure the secret names in the template metadata match those referenced in `values.yaml`
3. Test thoroughly in a non-production environment before deploying to production

All current and valid SealedSecrets are located in the parent directory. 