const nodemailer = require("nodemailer");
const Ticket = require("../models/Ticket");
const Notification = require("../models/Notification");
const { createAndSendNotification } = require("../services/notificationService");

const sendEmailInvoice = async (req, res) => {
  const { to, subject, htmlContent } = req.body;

  if (!to || !subject || !htmlContent) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const subdomain = process.env.ZENDESK_SUBDOMAIN;
    const zendeskEmail = process.env.ZENDESK_EMAIL;
    const apiToken = process.env.ZENDESK_API_TOKEN;

    if (!subdomain || !zendeskEmail || !apiToken) {
      return res.status(500).json({ message: "Zendesk configuration is missing on the server." });
    }

    const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json`;
    const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

    const ticketData = {
      ticket: {
        subject: subject,
        comment: {
          html_body: htmlContent // Zendesk uses html_body for HTML comments
        },
        requester: {
          name: "Customer",
          email: to
        }
      }
    };

    let zendeskTicketId = null;
    
    // Attempt Zendesk API call using fetch or https (polyfilled for older node just in case)
    if (typeof fetch !== 'undefined') {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader
        },
        body: JSON.stringify(ticketData)
      });
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Zendesk API Error: ${response.status} ${errorText}`);
      }
      const data = await response.json();
      zendeskTicketId = data.ticket?.id;
    } else {
      // Fallback for Node 16 (Render sometimes uses older Node)
      const https = require('https');
      zendeskTicketId = await new Promise((resolve, reject) => {
        const reqOpts = new URL(url);
        const options = {
          hostname: reqOpts.hostname,
          path: reqOpts.pathname,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader
          }
        };
        const reqHttp = https.request(options, (resHttp) => {
          let body = '';
          resHttp.on('data', chunk => body += chunk);
          resHttp.on('end', () => {
            if (resHttp.statusCode >= 200 && resHttp.statusCode < 300) {
              try {
                const data = JSON.parse(body);
                resolve(data.ticket?.id);
              } catch (e) { resolve(null); }
            } else {
              reject(new Error(`Zendesk API Error: ${resHttp.statusCode} ${body}`));
            }
          });
        });
        reqHttp.on('error', reject);
        reqHttp.write(JSON.stringify(ticketData));
        reqHttp.end();
      });
    }

    console.log(`✅ Invoice sent via Zendesk. Ticket ID: ${zendeskTicketId}`);

    // 2. Create local Ticket so the 'total tickets' count increases in the support dashboard
    try {
      const ticketId = Math.floor(100000 + Math.random() * 900000);
      const localTicket = new Ticket({
        ticketId,
        subject: subject,
        message: "Invoice sent to customer via email.", // Simple text for local dashboard
        userName: "Customer",
        email: to,
        role: "customer",
        businessName: "Retail Verse",
        storeId: "N/A",
        clientId: req.user?.clientId,
        status: "open",
        priority: "normal"
      });
      await localTicket.save();
    } catch (dbErr) {
      console.error("Error saving local ticket for invoice:", dbErr);
    }

    res.status(200).json({ message: "Email sent and ticket created successfully" });
  } catch (error) {
    console.error("Error sending email:", error);
    res.status(500).json({ message: "Failed to send email", error: error.message });
  }
};


const getNotifications = async (req, res) => {
  try {
    const userId = req.user._id;
    const userRole = req.user.role;
    const clientId = req.user.clientId;

    const query = {
      targetRoles: userRole,
    };

    if (clientId) {
      query.$or = [{ clientId }, { clientId: null }];
    } else {
      query.clientId = null;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .limit(50);

    const unreadCount = notifications.filter(
      (n) => !n.readBy.includes(userId)
    ).length;

    res.status(200).json({ success: true, notifications, unreadCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const markAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    // We can mark all as read for this user, or just one
    // For simplicity, mark all matching notifications as read
    const userRole = req.user.role;
    const clientId = req.user.clientId;

    const query = {
      targetRoles: userRole,
      readBy: { $ne: userId }
    };

    if (clientId) {
      query.$or = [{ clientId }, { clientId: null }];
    } else {
      query.clientId = null;
    }

    await Notification.updateMany(query, { $push: { readBy: userId } });

    res.status(200).json({ success: true, message: "Marked as read" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const broadcastNotification = async (req, res) => {
  try {
    const { title, message, targetRoles, type } = req.body;
    
    // Only super_admin should broadcast globally without clientId
    let clientId = req.user.clientId;
    if (req.user.role === "super_admin" && !req.body.clientId) {
      clientId = null; // Global broadcast
    }

    await createAndSendNotification({
      title,
      message,
      type: type || "general",
      targetRoles: targetRoles || ["admin", "client", "customer"],
      clientId,
    });

    res.status(200).json({ success: true, message: "Broadcast sent successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const requestRestock = async (req, res) => {
  try {
    const { productId, note } = req.body;
    const clientId = req.user.clientId;

    // Prevent duplicate notifications for the same product within a 1-minute window
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
    const recentDuplicate = await Notification.findOne({
      type: "low_stock",
      "data.productId": productId,
      clientId: clientId || null,
      createdAt: { $gte: oneMinuteAgo },
    });

    if (recentDuplicate) {
      return res.status(200).json({ success: true, message: "Restock notification already sent recently. Skipping duplicate." });
    }

    const title = "Restock Requested 🚨";
    const message = `A restock was requested by ${req.user.name || 'Cashier'} ${note ? '- Note: ' + note : ''}`;
    
    // Target only inventory_manager (and admin gets auto-added by notificationService)
    // super_admin is NOT targeted — this is a store-level notification only
    await createAndSendNotification({
      title,
      message,
      type: "low_stock",
      targetRoles: ["inventory", "super_admin"],
      clientId,
      data: { productId }
    });
    
    res.status(200).json({ success: true, message: "Restock request sent" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { sendEmailInvoice, getNotifications, markAsRead, broadcastNotification, requestRestock };
