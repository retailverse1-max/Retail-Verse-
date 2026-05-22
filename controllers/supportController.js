const Ticket = require("../models/Ticket");

// Helper to check if Zendesk is configured
const isZendeskConfigured = () => {
  const subdomain = process.env.ZENDESK_SUBDOMAIN;
  const zendeskEmail = process.env.ZENDESK_EMAIL;
  const apiToken = process.env.ZENDESK_API_TOKEN;
  return subdomain && zendeskEmail && apiToken;
};

// POST /api/support/ticket
exports.createTicket = async (req, res) => {
  try {
    const { subject, message, userName, email, role, businessName, storeId } = req.body;

    if (!subject || !message) {
      return res.status(400).json({ success: false, message: "Subject and message are required" });
    }

    // 1. Create ticket in local database first
    const ticketId = Math.floor(100000 + Math.random() * 900000);
    const localTicket = new Ticket({
      ticketId,
      subject,
      message,
      userName,
      email,
      role,
      businessName,
      storeId,
      status: "open",
      priority: "normal"
    });

    await localTicket.save();

    // 2. If Zendesk is configured, attempt to push in background
    let zendeskTicketId = null;
    if (isZendeskConfigured()) {
      try {
        const subdomain = process.env.ZENDESK_SUBDOMAIN;
        const zendeskEmail = process.env.ZENDESK_EMAIL;
        const apiToken = process.env.ZENDESK_API_TOKEN;

        const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json`;
        const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

        const ticketData = {
          ticket: {
            subject: subject,
            comment: {
              body: `
User Name: ${userName || 'N/A'}
Email: ${email || 'N/A'}
Role: ${role || 'N/A'}
Business: ${businessName || 'N/A'}
Store ID: ${storeId || 'N/A'}

Message:
${message}
              `.trim()
            },
            requester: {
              name: userName || "Retail Verse User",
              email: email || zendeskEmail
            }
          }
        };

        const response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": authHeader
          },
          body: JSON.stringify(ticketData)
        });

        if (response.ok) {
          const data = await response.json();
          zendeskTicketId = data.ticket?.id;
          console.log(`✅ Ticket synced to Zendesk. ID: ${zendeskTicketId}`);
        } else {
          console.error("Zendesk sync status not ok:", response.status);
        }
      } catch (zendeskErr) {
        console.error("Zendesk background sync failed:", zendeskErr.message);
      }
    } else {
      console.log("ℹ️ Zendesk not configured on server. Stored ticket locally.");
    }

    res.status(200).json({
      success: true,
      message: "Support ticket created successfully",
      ticketId: zendeskTicketId || ticketId
    });
  } catch (error) {
    console.error("Error creating support ticket:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// GET /api/support/stats
exports.getSupportStats = async (req, res) => {
  try {
    let total = 0, open = 0, resolved = 0, pending = 0;

    // 1. Get stats from Zendesk if configured
    if (isZendeskConfigured()) {
      try {
        const subdomain = process.env.ZENDESK_SUBDOMAIN;
        const zendeskEmail = process.env.ZENDESK_EMAIL;
        const apiToken = process.env.ZENDESK_API_TOKEN;

        const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');
        const fetchCount = async (query) => {
          const response = await fetch(`https://${subdomain}.zendesk.com/api/v2/search.json?query=${encodeURIComponent(query)}`, {
            headers: { "Authorization": authHeader }
          });
          const data = await response.json();
          return data.count || 0;
        };

        const [zTotal, zOpen, zResolved, zPending] = await Promise.all([
          fetchCount("type:ticket"),
          fetchCount("type:ticket status:open"),
          fetchCount("type:ticket status:solved"),
          fetchCount("type:ticket status:pending"),
        ]);

        total += zTotal;
        open += zOpen;
        resolved += zResolved;
        pending += zPending;
      } catch (zendeskErr) {
        console.error("Zendesk stats fetch failed:", zendeskErr.message);
      }
    }

    // 2. Aggregate from local MongoDB
    const localTotal = await Ticket.countDocuments();
    const localOpen = await Ticket.countDocuments({ status: "open" });
    const localResolved = await Ticket.countDocuments({ status: { $in: ["resolved", "closed", "solved"] } });
    const localPending = await Ticket.countDocuments({ status: "pending" });

    total += localTotal;
    open += localOpen;
    resolved += localResolved;
    pending += localPending;

    res.status(200).json({
      success: true,
      data: { total, open, resolved, pending }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// GET /api/support/tickets
exports.getRecentTickets = async (req, res) => {
  try {
    let tickets = [];

    // 1. Fetch from Zendesk if configured
    if (isZendeskConfigured()) {
      try {
        const subdomain = process.env.ZENDESK_SUBDOMAIN;
        const zendeskEmail = process.env.ZENDESK_EMAIL;
        const apiToken = process.env.ZENDESK_API_TOKEN;

        const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json?sort_by=created_at&sort_order=desc&per_page=10`;
        const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

        const response = await fetch(url, {
          headers: { "Authorization": authHeader }
        });
        const data = await response.json();
        
        if (data.tickets && Array.isArray(data.tickets)) {
          tickets = data.tickets.map(t => ({
            id: t.id,
            subject: t.subject,
            status: t.status,
            priority: t.priority || "normal",
            created_at: t.created_at,
            requester_name: t.requester_name || "User",
            requester_email: t.requester_email || ""
          }));
        }
      } catch (zendeskErr) {
        console.error("Zendesk tickets fetch failed:", zendeskErr.message);
      }
    }

    // 2. Fetch from local MongoDB
    const localTickets = await Ticket.find().sort({ createdAt: -1 }).limit(20);
    const mappedLocal = localTickets.map(t => ({
      id: t.ticketId,
      subject: t.subject,
      status: t.status,
      priority: t.priority || "normal",
      created_at: t.createdAt.toISOString(),
      requester_name: t.userName || "Retail Verse User",
      requester_email: t.email || ""
    }));

    // Combine them
    const combinedTickets = [...mappedLocal, ...tickets];

    res.status(200).json({
      success: true,
      tickets: combinedTickets
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// PUT /api/support/ticket/:id
exports.updateTicketStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      return res.status(400).json({ success: false, message: "Status is required" });
    }

    let ticket = await Ticket.findOneAndUpdate(
      { ticketId: Number(id) },
      { status },
      { new: true }
    );

    if (!ticket) {
      // Fallback: search by mongo _id if number matching fails
      try {
        ticket = await Ticket.findByIdAndUpdate(
          id,
          { status },
          { new: true }
        );
      } catch (err) {
        // Ignore cast error if not a valid ObjectId
      }
    }

    if (!ticket) {
      return res.status(404).json({ success: false, message: "Ticket not found" });
    }

    res.status(200).json({
      success: true,
      message: "Ticket status updated successfully",
      ticket
    });
  } catch (error) {
    console.error("Error updating support ticket status:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// DELETE /api/support/ticket/:id
exports.deleteTicket = async (req, res) => {
  try {
    const { id } = req.params;

    let ticket = await Ticket.findOneAndDelete({ ticketId: Number(id) });

    if (!ticket) {
      // Fallback: search by mongo _id
      try {
        ticket = await Ticket.findByIdAndDelete(id);
      } catch (err) {
        // Ignore cast error if not a valid ObjectId
      }
    }

    if (!ticket) {
      return res.status(404).json({ success: false, message: "Ticket not found" });
    }

    res.status(200).json({
      success: true,
      message: "Ticket deleted successfully"
    });
  } catch (error) {
    console.error("Error deleting support ticket:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

