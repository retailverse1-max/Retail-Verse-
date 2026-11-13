from PIL import Image

image_path = "/Users/sumitgupta/.gemini/antigravity-ide/brain/c98e0f1e-cf73-4942-8d1b-3583ce859031/.user_uploaded/media_1791374527265.png"
img = Image.open(image_path)
width, height = img.size

# We want to crop out the POS illustration in the center, ignoring the RETAIL VERSE text at the bottom.
# Let's say the POS is in the central 70% of the image.
crop_size = min(width, height) * 0.75
left = (width - crop_size) / 2
top = (height - crop_size) / 2 - (height * 0.08) # Shift up slightly to avoid bottom text
right = left + crop_size
bottom = top + crop_size

cropped_img = img.crop((left, top, right, bottom))
cropped_img.save("assets/images/logopos_cropped.png")
print("Cropped logo saved as assets/images/logopos_cropped.png")
