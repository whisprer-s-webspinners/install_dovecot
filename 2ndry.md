Mail Server Hardening and Forwarding Guide

You've successfully installed the core components of your mail server! Now, let's implement the essential security and delivery mechanisms: SPF, DKIM, DMARC, and then configure email forwarding.



1\. SPF (Sender Policy Framework)

SPF helps prevent email spoofing by allowing receiving mail servers to check if an email claiming to come from your domain (whispr.dev) is sent from an IP address authorized by your domain's administrators.



What it is: A DNS TXT record that lists the IP addresses or hostnames that are allowed to send email on behalf of your domain.



Why it's important: Prevents spammers from sending emails pretending to be from your domain, and improves your email deliverability.



How to set it up:

You need to add a TXT record to your domain's DNS settings (where whispr.dev is registered, e.g., DigitalOcean, GoDaddy, Cloudflare).



Record Type: TXT



Host/Name: @ (or yourdomain.com depending on your DNS provider's interface, meaning the root domain)



Value/Text:



v=spf1 mx a ip4:68.183.227.135 ~all



Explanation of the value:



v=spf1: Specifies the SPF version.



mx: Allows hosts listed in your domain's MX records to send mail.



a: Allows the IP address of your domain's A record (whispr.dev) to send mail.



ip4:68.183.227.135: Explicitly allows your server's IP address to send mail.



~all: A "softfail" policy. It means that emails from unauthorized senders might be spam, but not definitively. For stricter policies, you could use -all (hardfail), but ~all is safer to start with.



Action: Go to your domain registrar or DNS provider's control panel and add this TXT record.



2\. DKIM (DomainKeys Identified Mail)

DKIM adds a digital signature to your outgoing emails, allowing receiving servers to verify that the email hasn't been tampered with in transit and that it genuinely originated from your domain.



What it is: A cryptographic signature added to email headers, verified via a public key published in your DNS.



Why it's important: Prevents email tampering and further improves deliverability and trust.



How to set it up:



Step 2.1: Install OpenDKIM (if not already installed)

Your script might have installed it, but let's ensure.



sudo apt update

sudo apt install opendkim opendkim-tools -y



Step 2.2: Generate DKIM Keys

You'll generate a public and private key pair. The private key stays on your server, and the public key goes into your DNS.



\# Create a directory for DKIM keys

sudo mkdir -p /etc/opendkim/keys/$MAILDOMAIN



\# Generate the keys (replace 'default' with a selector name, e.g., 'mail' or '2024')

\# 'default' is a common selector.

sudo opendkim-genkey -b 2048 -d $MAILDOMAIN -s default -v -D /etc/opendkim/keys/$MAILDOMAIN



\# Adjust permissions

sudo chown -R opendkim:opendkim /etc/opendkim/keys

sudo chmod -R go-rw /etc/opendkim/keys



This will create two files in /etc/opendkim/keys/whispr.dev/: default.private (your private key) and default.txt (containing the public key for DNS).



Step 2.3: Configure OpenDKIM



Edit the main OpenDKIM configuration file:



sudo nano /etc/opendkim.conf



Add or ensure these lines are present/uncommented and configured:



AutoRestart             Yes

AutoRestartRate         10/1h

UMask                   002

Syslog                  Yes

SyslogSuccess           Yes

LogWhy                  Yes



\# Adjust to your needs

Canonicalization        relaxed/simple

Mode                    sv # s=sign, v=verify

SubDomains              No



\# Domain to sign for

Domain                  $MAILDOMAIN # Use your MAILDOMAIN variable here, e.g., whispr.dev



\# Path to the key table

KeyTable                refile:/etc/opendkim/KeyTable



\# Path to the signing table

SigningTable            refile:/etc/opendkim/SigningTable



\# Path to the trusted hosts file

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts

InternalHosts           refile:/etc/opendkim/TrustedHosts



\# Socket for Postfix to connect to OpenDKIM

Socket                  inet:12301@localhost # Or unix:/var/run/opendkim/opendkim.sock

PidFile                 /var/run/opendkim/opendkim.pid



Save and exit (Ctrl+X, Y, Enter).



Step 2.4: Configure KeyTable, SigningTable, and TrustedHosts



Create/edit these files:



sudo nano /etc/opendkim/KeyTable



Add this line (replace default if you used a different selector):



default.\_domainkey.$MAILDOMAIN $MAILDOMAIN:/etc/opendkim/keys/$MAILDOMAIN/default.private



Save and exit.



sudo nano /etc/opendkim/SigningTable



Add this line:



\*@$MAILDOMAIN default.\_domainkey.$MAILDOMAIN



Save and exit.



sudo nano /etc/opendkim/TrustedHosts



Add these lines:



127.0.0.1

localhost

10.0.0.0/8

172.16.0.0/12

192.168.0.0/16

\# Add your server's public IP if it's not covered by 127.0.0.1

\# 68.183.227.135



Save and exit.



Step 2.5: Configure Postfix to use OpenDKIM



Edit your Postfix main.cf:



sudo nano /etc/postfix/main.cf



Add these lines to the end of the file:



\# OpenDKIM configuration

milter\_protocol = 2

milter\_default\_action = accept

smtpd\_milters = inet:localhost:12301

non\_smtpd\_milters = inet:localhost:12301



Save and exit.



Step 2.6: Restart Services



sudo systemctl restart opendkim

sudo systemctl enable opendkim

sudo systemctl restart postfix



Step 2.7: Add DKIM Public Key to DNS

Now, you need to add another TXT record to your domain's DNS.



View your public key:



sudo cat /etc/opendkim/keys/$MAILDOMAIN/default.txt



You'll see output like:

default.\_domainkey IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."



Copy the entire string within the double quotes (starting with v=DKIM1; and ending before the final "). Some DNS providers require you to remove the quotes, others handle them. If your DNS provider splits long TXT records, you might need to concatenate them.



Add the TXT record:



Record Type: TXT



Host/Name: default.\_domainkey (or whatever selector you chose, followed by .\_domainkey)



Value/Text: Paste the copied string (e.g., v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...)



Action: Go to your domain registrar or DNS provider's control panel and add this TXT record.



3\. DMARC (Domain-based Message Authentication, Reporting, \& Conformance)

DMARC builds on SPF and DKIM, telling receiving servers what to do if an email fails SPF or DKIM checks, and allows you to receive reports on email authentication failures.



What it is: A DNS TXT record that defines policy for email authentication failures and where to send aggregate reports.



Why it's important: Provides a feedback loop for your domain's email, helps identify spoofing attempts, and further improves deliverability.



How to set it up:

Add another TXT record to your domain's DNS settings.



Record Type: TXT



Host/Name: \_dmarc



Value/Text:



v=DMARC1; p=none; rua=mailto:dmarc-reports@whispr.dev; ruf=mailto:dmarc-forensic@whispr.dev; fo=1;



Explanation of the value:



v=DMARC1: Specifies the DMARC version.



p=none: Policy for emails that fail DMARC. none means "do nothing" (monitor only). This is recommended to start, so you can analyze reports without impacting legitimate mail. You can later change it to quarantine (send to spam) or reject (block entirely).



rua=mailto:dmarc-reports@whispr.dev: Where to send aggregate reports (daily summaries). You must create this email address on your server or forward it elsewhere.



ruf=mailto:dmarc-forensic@whispr.dev: Where to send forensic reports (individual failure details). This can generate a lot of email, so use with caution. You might omit this initially.



fo=1: Generate forensic reports if any underlying authentication mechanism (SPF or DKIM) fails.



Action: Go to your domain registrar or DNS provider's control panel and add this TXT record. Remember to set up the dmarc-reports email address (and dmarc-forensic if you use it).



4\. Email Forwarding (tom@whispr.dev and cgpt@whispr.dev to phineaskfreak@yahoo.co.uk)

You can configure Postfix to forward emails for specific addresses. The most flexible way for multiple domains/addresses is using virtual\_alias\_maps.



How to set it up:



Step 4.1: Create/Edit the Virtual Alias Map File



sudo nano /etc/postfix/virtual



Add the forwarding rules. Each line has the local address followed by the destination address(es).



\# Forwarding for tom@whispr.dev

tom@whispr.dev phineaskfreak@yahoo.co.uk



\# Forwarding for cgpt@whispr.dev

cgpt@whispr.dev phineaskfreak@yahoo.co.uk



Save and exit.



Step 4.2: Update Postfix Configuration

Edit your Postfix main.cf again:



sudo nano /etc/postfix/main.cf



Add or modify these lines to tell Postfix to use your virtual file:



virtual\_alias\_domains = $MAILDOMAIN

virtual\_alias\_maps = hash:/etc/postfix/virtual



virtual\_alias\_domains: Tells Postfix which domains it handles virtual aliases for.



virtual\_alias\_maps: Specifies the file containing the alias mappings.



Save and exit.



Step 4.3: Create the Postfix Lookup Table

Postfix needs to convert the human-readable virtual file into a database format it can quickly look up.



sudo postmap /etc/postfix/virtual



This will create /etc/postfix/virtual.db.



Step 4.4: Restart Postfix



sudo systemctl restart postfix



Final Testing

After setting up DNS records, remember that DNS changes can take time to propagate (up to 48 hours, though often faster).



Check DNS Propagation: Use online tools like digwebinterface.com or mxtoolbox.com to check your SPF, DKIM, and DMARC TXT records for whispr.dev.



Send Test Emails: Send emails from your new mail server (e.g., from tom@whispr.dev or cgpt@whispr.dev if you configure a client for them, or by sending a test email from the server itself) to external services like Gmail or Yahoo.



Check Email Headers: In the received emails (e.g., in Gmail, click "Show original" or "View message details"), look for Authentication-Results headers. They should show spf=pass, dkim=pass, and dmarc=pass.



Test Forwarding: Send an email to tom@whispr.dev and cgpt@whispr.dev and verify they arrive at phineaskfreak@yahoo.co.uk.



You're well on your way to a fully functional and secure mail server!

