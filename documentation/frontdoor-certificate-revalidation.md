# Front door certificate revalidation

When a front door certificate is about to expire, we typically get statuscake alert(s) via text/email.
The following outlines the steps to revalidate the certificate:

1. Login to the azure portal
1. Create a PIM request
1. Once the PIM request is approved, go to the associated Front door
1. Select 'Settings' and then 'Domains' - you should see a red warning icon next to the domain that needs revalidation
1. For the domain, under 'Validate State' you'll see 'Pending revalidation' or 'Timeout'. Note that the certificate type should be 'AFD Managed' - select the 'Pending revalidation' or 'Timeout' link
1. Regenerate the TXT records
1. Then 'update' the 'DNS record status', which should show up after 'regenerate'

## Testing

It will take approximately 5 mins to process.

1. Confirm that the _dnsauth record for the entry has been updated in the DNS zone and the 'Validate State' is now set to 'Approved'
2. Check statuscake, you should see the new valid from <today>, valid to <+6 months>. 'Force test' if needed
