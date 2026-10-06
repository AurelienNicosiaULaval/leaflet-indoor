const { test, expect } = require("@playwright/test");

function collectErrors(page) {
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  return errors;
}

test("comment icons show only rooms with accounts, escape text, and follow floors", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("http://127.0.0.1:7357/comments.html");
  await expect(page).toHaveTitle("Indoor room comments");
  const icons = page.locator(".leaflet-indoor-comment-marker");
  await expect(icons).toHaveCount(2);
  const roomIcon = page.locator('[data-indoor-comment-id="feature-01"]');
  await expect(roomIcon).toHaveAttribute("role", "button");
  await expect(roomIcon).toHaveAttribute("aria-label", "Lire les témoignages: Meeting room");
  await expect(roomIcon).toHaveText("★");
  await roomIcon.click();
  const popup = page.getByRole("region", { name: "Témoignages" });
  await expect(popup).toHaveAttribute("data-indoor-comment-count", "2");
  await expect(popup.locator(".leaflet-indoor-comment-popup__text").first())
    .toHaveText("<img src=x onerror=alert(1)> & a plain-text comment");
  await expect(popup.locator("img, script")).toHaveCount(0);
  await expect(popup.locator(".leaflet-indoor-comment-popup__byline").first())
    .toHaveText("Example visitor A · 2026-10-06");
  await expect(popup.getByRole("link", { name: "Lire la source" }).first())
    .toHaveAttribute("href", "https://example.org/visitor-account");
  await expect(roomIcon).toHaveAttribute("aria-expanded", "true");
  await page.locator('[data-indoor-level="1"]').click();
  await expect(popup).toHaveCount(0);
  await expect(roomIcon).toHaveCount(0);
  await expect(icons).toHaveCount(2);
  await expect(page.locator('[data-indoor-comment-id="feature-06"]')).toBeVisible();
  await expect(page.locator('[data-indoor-comment-id="feature-04"]')).toBeVisible();
  expect(errors).toEqual([]);
});

test("comment icons support Enter, Space, Escape, and restore keyboard focus", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("http://127.0.0.1:7357/comments.html");
  const icon = page.locator('[data-indoor-comment-id="feature-01"]');
  const popup = page.getByRole("region", { name: "Témoignages" });
  for (const key of ["Enter", "Space"]) {
    await icon.focus();
    await page.keyboard.press(key);
    await expect(popup).toBeVisible();
    await expect(popup).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(popup).toHaveCount(0);
    await expect(icon).toBeFocused();
    await expect(icon).toHaveAttribute("aria-expanded", "false");
  }
  expect(errors).toEqual([]);
});

test("room comments coexist with photos and keep source links reachable on mobile", async ({ page }) => {
  const errors = collectErrors(page);
  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto("http://127.0.0.1:7357/comments.html");
  await page.locator('[data-indoor-comment-id="feature-01"]').tap();
  const popup = page.getByRole("region", { name: "Témoignages" });
  const lastSource = popup.getByRole("link", { name: "Lire la source" }).last();
  await lastSource.scrollIntoViewIfNeeded();
  await expect(lastSource).toBeInViewport();
  const bounds = await popup.boundingBox();
  expect(bounds.width).toBeLessThan(350);
  expect(bounds.height).toBeLessThanOrEqual(390);
  await page.keyboard.press("Escape");
  // Use a point away from the separate room icon.
  await page.locator(".leaflet-indoor-feature-1").click({ position: { x: 12, y: 12 } });
  await expect(page.locator('[data-indoor-photo-count="2"]')).toBeVisible();
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page.locator(".leaflet-indoor-photo-popup__caption")).toContainText("Window-side view");
  expect(errors).toEqual([]);
});

test("Louvre icons show verified accounts in the correct rooms and floors", async ({ page }) => {
  const errors = collectErrors(page);
  // Rendering and interaction are deterministic even when tile servers are unavailable.
  await page.route("https://*.tile.openstreetmap.org/**", route => route.fulfill({ status: 200, body: "" }));
  await page.goto("http://127.0.0.1:7357/louvre-comments.html");
  await expect(page).toHaveTitle("Louvre rooms and visitor accounts");
  const icons = page.locator(".leaflet-indoor-comment-marker");
  await expect(icons).toHaveCount(1);
  const venus = page.locator('[data-indoor-comment-id="osm-way-453817508"]');
  await venus.click();
  const popup = page.getByRole("region", { name: "Visitor accounts" });
  await expect(popup).toContainText("Jitka Tupa");
  await expect(popup).toContainText("Published account summary: Venus de Milo");
  await page.keyboard.press("Escape");
  await expect(popup).toHaveCount(0);
  await page.locator('[data-indoor-level="1"]').click();
  await expect(icons).toHaveCount(2);
  const states = page.locator('[data-indoor-comment-id="osm-way-492611500"]');
  await expect(states.locator("svg")).toHaveCount(1);
  await states.click();
  await expect(popup).toHaveAttribute("data-indoor-comment-count", "2");
  await expect(popup).toContainText("patricia_pham (UMass Lowell)");
  await expect(popup).toContainText("Jitka Tupa");
  await expect(popup.getByRole("link", { name: "Read the original account" }).first())
    .toHaveAttribute("href", /blogs\.uml\.edu/);
  await page.keyboard.press("Escape");
  await expect(popup).toHaveCount(0);
  await page.locator('[data-indoor-comment-id="osm-way-367790015"]').click();
  await expect(popup).toContainText("Michele (Malaysian Meanders)");
  await expect(popup).toContainText("Published 2013-09-04");
  await page.keyboard.press("Escape");
  await expect(popup).toHaveCount(0);
  await page.locator('[data-indoor-level="-2"]').click();
  await expect(icons).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("Shiny receives comment events and proxy replacement and clearing remove icons", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("http://127.0.0.1:7358", { waitUntil: "networkidle" });
  await page.locator('[data-indoor-level="1"]').click();
  await page.locator('[data-indoor-comment-id="feature-06"]').click();
  await expect(page.locator("#selected-comment")).toContainText('"feature-06"');
  await expect(page.locator("#selected-comment")).toContainText("comment_count");
  await expect(page.locator("#selected-feature")).toContainText("NULL");
  await page.getByRole("button", { name: "Hide comments" }).click();
  await expect(page.locator(".leaflet-indoor-comment-marker")).toHaveCount(0);
  await expect(page.locator(".leaflet-indoor-comment-popup")).toHaveCount(0);
  await expect(page.locator(".leaflet-indoor-feature").first()).toBeVisible();
  await page.getByRole("button", { name: "Clear indoor map" }).click();
  await expect(page.locator(".leaflet-indoor-feature")).toHaveCount(0);
  await expect(page.locator(".leaflet-indoor-control")).toContainText("No levels");
  expect(errors).toEqual([]);
});
