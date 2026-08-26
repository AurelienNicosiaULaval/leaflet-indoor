const { test, expect } = require("@playwright/test");

function collectConsoleErrors(page) {
  const errors = [];
  page.on("console", message => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", error => errors.push(error.message));
  return errors;
}

test("initial control, floor order, switching, and ARIA state", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/single.html");
  const control = page.locator('[data-indoor-control-id="indoor"]');
  await expect(control).toBeVisible();
  await expect(control.locator('[role="radiogroup"]')).toHaveAttribute("aria-label", "Floor");

  const buttons = control.locator("button");
  await expect(buttons).toHaveCount(3);
  await expect(buttons).toHaveText(["2", "1", "0"]);
  await expect(control.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "true");
  await expect(page.locator(".leaflet-indoor-feature-1")).toBeVisible();
  await expect(page.locator(".leaflet-indoor-feature-6")).toHaveCount(0);

  await control.locator('[data-indoor-level="1"]').click();
  await expect(control.locator('[data-indoor-level="1"]')).toHaveAttribute("aria-checked", "true");
  await expect(control.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "false");
  await expect(page.locator(".leaflet-indoor-feature-1")).toHaveCount(0);
  await expect(page.locator(".leaflet-indoor-feature-6")).toBeVisible();
  expect(errors).toEqual([]);
});

test("keyboard navigation changes the active floor and preserves focus", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/single.html");
  const floorZero = page.locator('[data-indoor-control-id="indoor"] [data-indoor-level="0"]');
  await floorZero.focus();
  await page.keyboard.press("ArrowUp");
  const floorOne = page.locator('[data-indoor-control-id="indoor"] [data-indoor-level="1"]');
  await expect(floorOne).toBeFocused();
  await expect(floorOne).toHaveAttribute("aria-checked", "true");
  await page.keyboard.press("Home");
  const floorTwo = page.locator('[data-indoor-control-id="indoor"] [data-indoor-level="2"]');
  await expect(floorTwo).toBeFocused();
  await expect(floorTwo).toHaveAttribute("aria-checked", "true");
  expect(errors).toEqual([]);
});

test("two maps keep independent state", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/two-maps.html");
  const first = page.locator("#map-one");
  const second = page.locator("#map-two");
  await expect(first.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "true");
  await expect(second.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "true");
  await first.locator('[data-indoor-level="2"]').click();
  await expect(first.locator('[data-indoor-level="2"]')).toHaveAttribute("aria-checked", "true");
  await expect(second.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "true");
  expect(errors).toEqual([]);
});

test("multiple data sets on one map remain independent", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/multi-data.html");
  const rooms = page.locator('[data-indoor-control-id="rooms-control"]');
  const services = page.locator('[data-indoor-control-id="services-control"]');
  await expect(rooms.locator('[data-indoor-level="0"]')).toHaveAttribute("aria-checked", "true");
  await expect(services.locator('[data-indoor-level="1"]')).toHaveAttribute("aria-checked", "true");
  await rooms.locator('[data-indoor-level="2"]').click();
  await expect(rooms.locator('[data-indoor-level="2"]')).toHaveAttribute("aria-checked", "true");
  await expect(services.locator('[data-indoor-level="1"]')).toHaveAttribute("aria-checked", "true");
  expect(errors).toEqual([]);
});

test("local and geographic maps render vector features without console errors", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/geographic.html");
  await expect(page.locator("#geographic-map .leaflet-indoor-control")).toBeVisible();
  await expect(page.locator("#geographic-map .leaflet-indoor-feature").first()).toBeVisible();
  expect(errors).toEqual([]);
});

test("R Markdown and Quarto documents render interactive controls", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  for (const document of ["rmarkdown-example.html", "quarto-example.html"]) {
    const response = await page.goto(`http://127.0.0.1:7357/${document}`);
    expect(response.status()).toBe(200);
    const control = page.locator('[data-indoor-control-id="indoor"]');
    await expect(control).toBeVisible();
    await control.locator('[data-indoor-level="2"]').click();
    await expect(control.locator('[data-indoor-level="2"]')).toHaveAttribute("aria-checked", "true");
  }
  expect(errors).toEqual([]);
});

test("mobile viewport remains usable and produces a reference capture", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto("http://127.0.0.1:7357/single.html");
  const control = page.locator('[data-indoor-control-id="indoor"]');
  await expect(control).toBeInViewport();
  const box = await control.boundingBox();
  expect(box.width).toBeLessThan(200);
  expect(box.height).toBeLessThan(400);
  await control.locator('[data-indoor-level="2"]').tap();
  await expect(control.locator('[data-indoor-level="2"]')).toHaveAttribute("aria-checked", "true");
  const capture = await control.screenshot({
    path: "../../output/playwright/indoor-control-reference.png",
    animations: "disabled"
  });
  expect(capture.length).toBeGreaterThan(1000);
  expect(errors).toEqual([]);
});

test("Shiny receives floor and feature events and proxy updates the map", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7358", { waitUntil: "networkidle" });
  const control = page.locator('[data-indoor-control-id="indoor"]');
  await expect(control).toBeVisible();
  await control.locator('[data-indoor-level="1"]').click();
  await expect(page.locator("#selected-floor")).toContainText('"1"');
  await expect(page.locator("#selected-floor")).toContainText('"indoor"');

  await page.locator(".leaflet-indoor-feature-6").click({ position: { x: 2, y: 2 } });
  await expect(page.locator("#selected-feature")).toContainText('"feature-06"');

  await page.getByRole("button", { name: "Show floor 2" }).click();
  await expect(control.locator('[data-indoor-level="2"]')).toHaveAttribute("aria-checked", "true");
  expect(errors).toEqual([]);
});
