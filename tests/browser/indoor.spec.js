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

test("room photos keep captions paired in the carousel and enlarged dialog", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/photo-carousel.html");
  await page.locator("#photo-map .leaflet-indoor-feature-1").click();

  const carousel = page.locator('[data-indoor-photo-count="2"]');
  await expect(carousel).toBeVisible();
  await expect(carousel).toHaveAttribute("aria-label", "Photos de la pièce");
  await expect(carousel.locator(".leaflet-indoor-photo-popup__introduction"))
    .toContainText("Synthetic meeting room on floor 0.");

  const image = carousel.locator(".leaflet-indoor-photo-popup__image");
  const caption = carousel.locator(".leaflet-indoor-photo-popup__caption");
  const firstSource = await image.getAttribute("src");
  expect(firstSource).toMatch(/^data:image\/svg\+xml;base64,/);
  await expect(caption).toHaveText("Entrance view of the synthetic meeting room.");
  expect(await image.evaluate(node => node.nextElementSibling === node.parentElement.querySelector("figcaption")))
    .toBe(true);

  await carousel.getByRole("button", { name: "Suivant" }).click();
  await expect(caption).toContainText("Window-side view");
  await expect(carousel.locator(".leaflet-indoor-photo-popup__counter"))
    .toHaveText("Photo 2 sur 2");
  expect(await image.getAttribute("src")).not.toBe(firstSource);
  expect(await caption.evaluate(node => node.scrollHeight === node.clientHeight)).toBe(true);

  const enlarge = carousel.getByRole("button", { name: "Agrandir" });
  await expect(enlarge).toBeVisible();
  await enlarge.click();
  const dialog = page.getByRole("dialog", { name: "Photo agrandie de la pièce" });
  await expect(dialog).toBeVisible();
  await expect(dialog.locator(".leaflet-indoor-photo-dialog__caption"))
    .toHaveText(await caption.textContent());
  await expect(dialog.locator(".leaflet-indoor-photo-dialog__image"))
    .toHaveAttribute("src", await image.getAttribute("src"));
  await page.keyboard.press("Tab");
  await expect(dialog.getByRole("button", { name: "Fermer" })).toBeFocused();
  await dialog.getByRole("button", { name: "Fermer" }).click();
  await expect(dialog).toHaveCount(0);
  await expect(enlarge).toBeFocused();
  expect(errors).toEqual([]);
});

test("features without photos retain their ordinary popup", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.goto("http://127.0.0.1:7357/photo-carousel.html");
  await page.locator('#photo-map [data-indoor-level="1"]').click();
  await page.locator("#photo-map .leaflet-indoor-feature-6").click();
  await expect(page.locator("#photo-map .leaflet-popup-content"))
    .toHaveText("Synthetic reading room on floor 1.");
  await expect(page.locator("#photo-map .leaflet-indoor-photo-popup")).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("photo controls remain reachable with a long caption on mobile", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto("http://127.0.0.1:7357/photo-carousel.html");
  await page.locator("#photo-map .leaflet-indoor-feature-1").tap();
  const carousel = page.locator(".leaflet-indoor-photo-popup");
  const floorControl = page.locator("#photo-map .leaflet-indoor-control");
  await expect(floorControl).toBeHidden();
  await carousel.getByRole("button", { name: "Suivant" }).tap();
  const enlarge = carousel.getByRole("button", { name: "Agrandir" });
  await enlarge.scrollIntoViewIfNeeded();
  await expect(enlarge).toBeVisible();
  const metrics = await carousel.evaluate(node => ({
    clientHeight: node.clientHeight,
    scrollHeight: node.scrollHeight,
    captionHeight: node.querySelector("figcaption").scrollHeight
  }));
  expect(metrics.clientHeight).toBeGreaterThan(0);
  expect(metrics.scrollHeight).toBeGreaterThanOrEqual(metrics.clientHeight);
  expect(metrics.captionHeight).toBeGreaterThan(0);
  await enlarge.tap();
  const panel = page.locator(".leaflet-indoor-photo-dialog__panel");
  await expect(panel).toBeVisible();
  const panelBox = await panel.boundingBox();
  expect(panelBox.height).toBeLessThanOrEqual(690);
  await page.keyboard.press("Escape");
  await expect(panel).toHaveCount(0);
  await page.locator("#photo-map .leaflet-popup-close-button").click();
  await expect(floorControl).toBeVisible();
  expect(errors).toEqual([]);
});

test("real Louvre data, photos, floors, and base map work together", async ({ page }) => {
  const errors = collectConsoleErrors(page);
  const response = await page.goto("http://127.0.0.1:7357/real-world.html");
  expect(response.status()).toBe(200);

  const map = page.locator("#louvre-map");
  await expect(map.locator(".leaflet-tile-pane")).toHaveCount(1);
  await expect(map.locator(".leaflet-tile-loaded").first()).toBeVisible();
  await expect(map.locator(".leaflet-tile-loaded").first())
    .toHaveAttribute("src", /tile\.openstreetmap\.org/);
  await expect(map.locator(".leaflet-control-attribution"))
    .toContainText("OpenStreetMap");
  const floorControl = map.locator('[data-indoor-control-id="indoor"]');
  await expect(floorControl.locator("button")).toHaveText(["1", "0", "-2"]);
  await expect(floorControl.locator('[data-indoor-level="0"]'))
    .toHaveAttribute("aria-checked", "true");

  await map.locator(".leaflet-indoor-feature-54").click();
  const carousel = map.locator('[data-indoor-photo-count="2"]');
  await expect(carousel).toBeVisible();
  const image = carousel.locator(".leaflet-indoor-photo-popup__image");
  const caption = carousel.locator(".leaflet-indoor-photo-popup__caption");
  const firstSource = await image.getAttribute("src");
  expect(firstSource).toMatch(/^data:image\/jpeg;base64,/);
  await expect(caption).toContainText("Wilfredor, CC0 1.0");

  await carousel.getByRole("button", { name: "Next" }).click();
  await expect(caption).toContainText("Tangopaso, public domain");
  expect(await image.getAttribute("src")).not.toBe(firstSource);
  await carousel.getByRole("button", { name: "Enlarge" }).click();
  const dialog = page.getByRole("dialog", { name: "Enlarged room photo" });
  await expect(dialog.locator("figcaption")).toHaveText(await caption.textContent());

  await page.keyboard.press("Escape");
  await map.locator(".leaflet-popup-close-button").last().click();
  await map.locator(".leaflet-indoor-feature-53").click();
  const venusPhoto = map.locator('[data-indoor-photo-count="1"]');
  await expect(venusPhoto.locator("figcaption"))
    .toContainText("Shonagon, CC0 1.0");
  await expect(venusPhoto.getByRole("button", { name: "Enlarge" })).toBeVisible();
  const venusLayout = await venusPhoto.evaluate(node => ({
    clientHeight: node.clientHeight,
    scrollHeight: node.scrollHeight,
    captionBottom: node.querySelector("figcaption").getBoundingClientRect().bottom,
    actionsTop: node.querySelector(".leaflet-indoor-photo-popup__actions")
      .getBoundingClientRect().top
  }));
  expect(venusLayout.scrollHeight).toBeLessThanOrEqual(venusLayout.clientHeight + 1);
  expect(venusLayout.captionBottom).toBeLessThanOrEqual(venusLayout.actionsTop + 1);
  const mapBox = await map.boundingBox();
  const popupBox = await map.locator(".leaflet-popup").last().boundingBox();
  expect(popupBox.y).toBeGreaterThanOrEqual(mapBox.y - 2);
  expect(popupBox.y + popupBox.height)
    .toBeLessThanOrEqual(mapBox.y + mapBox.height + 2);
  await map.locator(".leaflet-popup-close-button").last().click();

  await floorControl.locator('[data-indoor-level="1"]').click();
  await expect(floorControl.locator('[data-indoor-level="1"]'))
    .toHaveAttribute("aria-checked", "true");
  await expect(map.locator(".leaflet-indoor-feature-54")).toHaveCount(0);
  await map.locator(".leaflet-indoor-feature-86").click();
  const apollonCarousel = map.locator('[data-indoor-photo-count="2"]').last();
  await expect(apollonCarousel.locator("figcaption"))
    .toContainText("Galerie d'Apollon");
  await apollonCarousel.getByRole("button", { name: "Next" }).click();
  await expect(apollonCarousel.locator("figcaption"))
    .toContainText("Gary Todd, CC0 1.0");
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
