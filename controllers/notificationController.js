const nodemailer = require("nodemailer");

const sendEmailInvoice = async (req, res) => {
  const { to, subject, htmlContent } = req.body;

  if (!to || !subject || !htmlContent) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // We expect the user to provide GMAIL_USER and GMAIL_PASS in their Render environment variables
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_PASS, // App Password, not regular password
      },
    });

    const mailOptions = {
      from: `"Retail Verse" <\${process.env.GMAIL_USER}>`,
      to,
      subject,
      html: htmlContent,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Message sent: %s", info.messageId);

    res.status(200).json({ message: "Email sent successfully" });
  } catch (error) {
    console.error("Error sending email:", error);
    res.status(500).json({ message: "Failed to send email", error: error.message });
  }
};

module.exports = { sendEmailInvoice };
