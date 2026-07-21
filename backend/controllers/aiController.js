const { GoogleGenerativeAI } = require("@google/generative-ai");

exports.scanProductImage = async (req, res) => {
  try {
    const rawKey = process.env.GEMINI_API_KEY;
    const apiKey = rawKey ? rawKey.replace(/['"]/g, "").trim() : "";

    // Check if AI is configured
    if (!apiKey || apiKey === "YOUR_GEMINI_KEY_HERE" || apiKey === "") {
      return res.status(503).json({
        success: false,
        message: "AI service not configured. Missing GEMINI_API_KEY in backend environment.",
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image file provided.",
      });
    }

    // Initialize Gemini
    const genAI = new GoogleGenerativeAI(apiKey);
    
    let mimeType = req.file.mimetype;
    // Fallback if mimetype is generic or missing
    if (!mimeType || mimeType === 'application/octet-stream') {
      const originalName = req.file.originalname || '';
      const parts = originalName.split('.');
      const ext = parts.length > 1 ? parts[parts.length - 1].toLowerCase() : '';
      if (ext === 'png') {
        mimeType = 'image/png';
      } else if (ext === 'webp') {
        mimeType = 'image/webp';
      } else if (ext === 'gif') {
        mimeType = 'image/gif';
      } else {
        mimeType = 'image/jpeg'; // Default safe fallback for product photo scan
      }
      console.log(`Deduced mimeType fallback: ${mimeType} for file: ${originalName}`);
    }

    const imagePart = {
      inlineData: {
        data: req.file.buffer.toString("base64"),
        mimeType: mimeType,
      },
    };

    const prompt = `You are an expert retail and inventory AI assistant. Analyze this product image.
Please return your response STRICTLY as a valid JSON object without any markdown formatting, code blocks, or extra text.

The JSON MUST contain the following keys exactly:
{
  "name": "A clear, concise, and professional product name",
  "category": "The best fitting retail category (e.g., Electronics, Groceries, Tools, Apparel)",
  "description": "A detailed, professional description suitable for an e-commerce or POS system",
  "tags": ["array", "of", "relevant", "search", "keywords"],
  "confidence": 0.95,
  "priceEstimate": 29.99
}`;

    const modelsToTry = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"];
    let result = null;
    let lastError = null;

    for (const modelName of modelsToTry) {
      try {
        const model = genAI.getGenerativeModel({ model: modelName });
        result = await model.generateContent([prompt, imagePart]);
        if (result && result.response) {
          console.log(`Successfully used model: ${modelName}`);
          break; // Stop trying if successful
        }
      } catch (e) {
        console.warn(`Model ${modelName} failed:`, e.message);
        lastError = e;
      }
    }

    if (!result || !result.response) {
      let availableModelsStr = "Could not fetch models.";
      try {
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
        const data = await response.json();
        if (data.models) {
          availableModelsStr = data.models.map(m => m.name).join(', ');
        } else {
          availableModelsStr = JSON.stringify(data);
        }
      } catch (fetchErr) {
        availableModelsStr = fetchErr.message;
      }
      throw new Error(`All Gemini models failed. Available models on your key: ${availableModelsStr}. Last error: ${lastError?.message}`);
    }

    const responseText = result.response.text();

    // Clean up potential markdown formatting from Gemini
    let cleanText = responseText.trim();
    cleanText = cleanText.replace(/^```json/i, "").replace(/^```/i, "").replace(/```$/i, "").trim();

    let parsedJson;
    try {
      parsedJson = JSON.parse(cleanText);
    } catch (parseError) {
      console.error("Failed to parse Gemini response as JSON:", cleanText);
      return res.status(500).json({
        success: false,
        message: "AI returned an invalid JSON format: " + cleanText.substring(0, 150),
      });
    }

    return res.status(200).json({
      success: true,
      data: parsedJson,
    });
  } catch (error) {
    console.error("AI Scan Error:", error);
    
    return res.status(500).json({
      success: false,
      message: error.message ? `AI Error: ${error.message}` : "An error occurred while communicating with the AI service.",
    });
  }
};
