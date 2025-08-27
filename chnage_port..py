import os
import shutil
import subprocess

def run_command(command, error_message):
    """
    Runs a shell command and raises an exception if it fails.
    """
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {error_message}")
        raise e

def configure_postfix():
    """
    Configures Postfix to use an external SMTP relay host.
    """
    # --- Get user input ---
    relay_host = input("Enter the SMTP relay host (e.g., [smtp.sendgrid.net]:587): ")
    username = input("Enter your SMTP relay username: ")
    password = input("Enter your SMTP relay password: ")

    # --- Define file paths ---
    main_cf_path = "/etc/postfix/main.cf"
    sasl_password_path = "/etc/postfix/sasl_password"

    # --- Step 1: Backup the original main.cf file ---
    print(f"\n1. Backing up {main_cf_path} to {main_cf_path}.bak")
    shutil.copyfile(main_cf_path, f"{main_cf_path}.bak")
    print("   Backup complete.")

    # --- Step 2: Clean and configure main.cf ---
    print("\n2. Cleaning and configuring main.cf...")
    
    # Read the content, filter out any duplicate lines, and add the new configuration
    with open(main_cf_path, 'r') as f:
        lines = f.readlines()

    with open(main_cf_path, 'w') as f:
        # Write back the original content, excluding the problematic trailing lines
        # This prevents duplication and configuration conflicts
        for line in lines:
            if not line.strip() in ["inet_protocols = all", "myhostname = mail.whispr.dev", "myorigin = /etc/mailname",
                                     "mydestination = whispr.dev,localhost", "relayhost = ", "mailbox_size_limit = 0",
                                     "recipient_delimiter = +", "inet_interfaces = all"]:
                f.write(line)

        # Add the new relayhost and SASL configuration to the end of the file
        f.write("\n# SMTP RELAY CONFIGURATION\n")
        f.write("# This section was added to route all outbound mail through a relay host\n")
        f.write(f"relayhost = {relay_host}\n")
        f.write("smtp_sasl_auth_enable = yes\n")
        f.write("smtp_sasl_password_maps = hash:/etc/postfix/sasl_password\n")
        f.write("smtp_sasl_security_options = noanonymous\n")
        f.write("smtp_sasl_tls_security_options = noanonymous\n")
    print("   main.cf configured.")

    # --- Step 3: Create and secure the SASL password file ---
    print("\n3. Creating and securing the SASL password file...")
    
    # Write the credentials to the file
    with open(sasl_password_path, 'w') as f:
        f.write(f"{relay_host} {username}:{password}\n")

    # Build the database and set permissions
    run_command(f"postmap {sasl_password_path}", "Failed to run postmap")
    run_command(f"chown root:root {sasl_password_path}*", "Failed to change file ownership")
    run_command(f"chmod 600 {sasl_password_path}*", "Failed to set file permissions")
    print("   sasl_password created and secured.")

    # --- Step 4: Restart Postfix to apply changes ---
    print("\n4. Restarting Postfix service...")
    run_command("sudo systemctl restart postfix", "Failed to restart Postfix. Check logs with 'sudo tail -f /var/log/mail.log'")
    print("   Postfix restarted successfully.")
    
    print("\n\nPostfix has been reconfigured to use the SMTP relay. You can now try sending a test email.")

if __name__ == "__main__":
    configure_postfix()
