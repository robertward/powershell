$smtpServer = "email-smtp.us-east-1.amazonaws.com"
$smtpPort = 587
$username = "ACCESS_KEY"
$password = "SECRET_KEY"
$from = "VERIFIED_ADDRESS"
$to = "EMAIL_ADDRESS"
$subject = "Test e-mail with PowerShell"
$body = "This is a test e-mail sending with using PowerShell"
     
$smtp = new-object Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtp.EnableSsl = $true
     
$smtp.Credentials = new-object Net.NetworkCredential($username, $password)
$msg = new-object Net.Mail.MailMessage
$msg.From = $from
$msg.To.Add($to)
$msg.Subject = $subject
$msg.Body = $body
$smtp.Send($msg)