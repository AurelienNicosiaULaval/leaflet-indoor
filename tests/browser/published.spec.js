const { test, expect } = require("@playwright/test");

test.skip(!process.env.PUBLISHED_BASE_URL, "PUBLISHED_BASE_URL is required");

test("published pkgdown site and interactive article are reachable", async ({ page }) => {
  const errors = [];
  page.on("console", message => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", error => errors.push(error.message));
  const base = process.env.PUBLISHED_BASE_URL.replace(/\/$/, "");

  const response = await page.goto(base + "/", { waitUntil: "networkidle" });
  expect(response.status()).toBe(200);
  await expect(page).toHaveTitle(/leaflet\.indoor/);
  await expect(page.getByRole("heading", { name: "leaflet.indoor" })).toBeVisible();

  const reference = await page.goto(base + "/reference/addIndoor.html", { waitUntil: "networkidle" });
  expect(reference.status()).toBe(200);
  await expect(page.getByRole("heading", { name: /Add multi-level indoor features/ })).toBeVisible();

  const article = await page.goto(base + "/articles/get-started.html", { waitUntil: "networkidle" });
  expect(article.status()).toBe(200);
  const control = page.locator(".leaflet-indoor-control").first();
  await expect(control).toBeVisible();
  await control.locator('[data-indoor-level="1"]').click();
  await expect(control.locator('[data-indoor-level="1"]')).toHaveAttribute("aria-checked", "true");

  const shiny = await page.goto(base + "/articles/shiny.html", { waitUntil: "networkidle" });
  expect(shiny.status()).toBe(200);
  await expect(page.getByRole("heading", { name: "Shiny integration" })).toBeVisible();

  const formats = await page.goto(base + "/articles/data-formats.html", { waitUntil: "networkidle" });
  expect(formats.status()).toBe(200);
  await expect(page.getByRole("heading", { name: "Indoor data formats" })).toBeVisible();

  const coordinates = await page.goto(base + "/articles/coordinate-systems.html", { waitUntil: "networkidle" });
  expect(coordinates.status()).toBe(200);
  await expect(page.getByRole("heading", { name: "Coordinate systems" })).toBeVisible();

  const photos = await page.goto(base + "/articles/photo-carousels.html", { waitUntil: "networkidle" });
  expect(photos.status()).toBe(200);
  await expect(page.getByRole("heading", {
    name: "A real-world indoor map with room photos"
  })).toBeVisible();
  const realMap = page.locator(".leaflet.html-widget").last();
  await expect(realMap.locator(".leaflet-tile-loaded").first()).toBeVisible();
  await expect(realMap.locator(".leaflet-indoor-feature")).toHaveCount(51);
  await realMap.locator(".leaflet-indoor-feature-54").click();
  const carousel = realMap.locator('[data-indoor-photo-count="2"]');
  await expect(carousel).toBeVisible();
  await expect(carousel.locator("figcaption")).toContainText("Wilfredor, CC0 1.0");
  await carousel.getByRole("button", { name: "Next" }).click();
  await expect(carousel.locator("figcaption")).toContainText("Tangopaso, public domain");
  await realMap.locator(".leaflet-popup-close-button").last().click();
  await realMap.locator(".leaflet-indoor-feature-53").click();
  await expect(realMap.locator('[data-indoor-photo-count="1"] figcaption'))
    .toContainText("Shonagon, CC0 1.0");
  await realMap.locator(".leaflet-popup-close-button").last().click();
  await realMap.locator('[data-indoor-level="1"]').click();
  await realMap.locator(".leaflet-indoor-feature-86").click();
  const apollon = realMap.locator('[data-indoor-photo-count="2"]').last();
  await expect(apollon.locator("figcaption")).toContainText("Galerie d'Apollon");
  await apollon.getByRole("button", { name: "Next" }).click();
  await expect(apollon.locator("figcaption")).toContainText("Gary Todd, CC0 1.0");

  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto(base + "/articles/photo-carousels.html", { waitUntil: "networkidle" });
  await expect(page.locator(".navbar-toggler")).toBeVisible();
  await page.locator(".navbar-toggler").click();
  await expect(page.getByRole("link", { name: "Reference" })).toBeVisible();
  await page.locator(".navbar-toggler").click();
  const mobileMap = page.locator(".leaflet.html-widget").last();
  await mobileMap.scrollIntoViewIfNeeded();
  await mobileMap.locator(".leaflet-indoor-feature-54").click();
  const mobileCarousel = mobileMap.locator('[data-indoor-photo-count="2"]');
  await mobileCarousel.getByRole("button", { name: "Next" }).click();
  await expect(mobileCarousel.getByRole("button", { name: "Enlarge" }))
    .toBeVisible();
  const mobileLayout = await page.evaluate(() => ({
    documentWidth: document.documentElement.scrollWidth,
    viewportWidth: window.innerWidth
  }));
  expect(mobileLayout.documentWidth).toBeLessThanOrEqual(mobileLayout.viewportWidth);
  expect(errors).toEqual([]);
});

for (const mobile of [false, true]) {
  test(`published room accounts keep room photos separately clickable${mobile ? " on mobile" : " on desktop"}`, async ({ page }) => {
    const errors = [];
    page.on("pageerror", error => errors.push(error.stack || error.message));
    if (mobile) await page.setViewportSize({ width: 390, height: 700 });
    // This scenario verifies the published widget independently of tile availability.
    await page.route("https://*.tile.openstreetmap.org/**", route => route.fulfill({ status: 200, body: "" }));
    const base = process.env.PUBLISHED_BASE_URL.replace(/\/$/, "");
    const reference = await page.goto(base + "/reference/indoorCommentOptions.html");
    expect(reference.status()).toBe(200);
    await expect(page.locator("main")).toContainText('placement = "edge"');
    const article = await page.goto(base + "/articles/room-comments.html");
    expect(article.status()).toBe(200);
    await expect(page.getByRole("heading", { name: "Room comments and visitor accounts", exact: true })).toBeVisible();
    const map = page.locator(".leaflet.html-widget").last();
    await map.scrollIntoViewIfNeeded();
    const venus = map.locator('[data-indoor-comment-id="osm-way-453817508"]');
    await expect(venus).toBeVisible();
    await expect(map.locator(".leaflet-indoor-comment-connector")).toHaveCount(1);
    await map.locator(".leaflet-indoor-feature-53").click();
    await expect(map.locator('[data-indoor-photo-count="1"]')).toBeVisible();
    await expect(map.locator(".leaflet-indoor-comment-popup")).toHaveCount(0);
    await map.locator(".leaflet-popup-close-button").click();
    await venus.click();
    const accounts = map.getByRole("region", { name: "Visitor accounts" });
    await expect(accounts).toContainText("Jitka Tupa");
    await expect(accounts.getByRole("link", { name: "Read the original account" }))
      .toHaveAttribute("href", "https://flyingoffcourse.wordpress.com/2015/09/24/visiting-my-three-muses-at-the-louvre/");
    await expect(map.locator(".leaflet-indoor-photo-popup")).toHaveCount(0);
    await page.keyboard.press("Escape");
    await map.locator('[data-indoor-level="1"]').click();
    await expect(map.locator(".leaflet-indoor-comment-marker")).toHaveCount(2);
    await map.locator('[data-indoor-comment-id="osm-way-492611500"]').click();
    await expect(accounts).toHaveAttribute("data-indoor-comment-count", "2");
    await expect(accounts).toContainText("patricia_pham (UMass Lowell)");
    await page.keyboard.press("Escape");
    await map.locator('[data-indoor-level="-2"]').click();
    await expect(map.locator(".leaflet-indoor-comment-marker")).toHaveCount(0);
    expect(errors).toEqual([]);
  });
}
