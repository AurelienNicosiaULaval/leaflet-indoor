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

  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto(base + "/articles/get-started.html", { waitUntil: "networkidle" });
  await expect(page.locator(".navbar-toggler")).toBeVisible();
  await page.locator(".navbar-toggler").click();
  await expect(page.getByRole("link", { name: "Reference" })).toBeVisible();
  const mobileControl = page.locator(".leaflet-indoor-control").first();
  await mobileControl.scrollIntoViewIfNeeded();
  await expect(mobileControl).toBeInViewport();
  const mobileLayout = await page.evaluate(() => ({
    documentWidth: document.documentElement.scrollWidth,
    viewportWidth: window.innerWidth
  }));
  expect(mobileLayout.documentWidth).toBeLessThanOrEqual(mobileLayout.viewportWidth);
  expect(errors).toEqual([]);
});
