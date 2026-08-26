const { defineConfig } = require("@playwright/test");

const published = process.env.PUBLISHED_BASE_URL;

module.exports = defineConfig({
  testDir: ".",
  testMatch: /.*\.spec\.js/,
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  timeout: 30000,
  reporter: process.env.CI ? [["line"], ["html", { open: "never" }]] : "line",
  outputDir: "../../output/playwright/test-results",
  use: {
    browserName: "chromium",
    headless: true,
    hasTouch: true,
    trace: "retain-on-failure",
    screenshot: "only-on-failure"
  },
  webServer: published ? undefined : [
    {
      command: "python3 -m http.server 7357 --bind 127.0.0.1 --directory output",
      port: 7357,
      reuseExistingServer: !process.env.CI,
      timeout: 120000
    },
    {
      command: "Rscript -e \"shiny::runApp(system.file('examples/shiny', package='leaflet.indoor'), host='127.0.0.1', port=7358, launch.browser=FALSE)\"",
      port: 7358,
      reuseExistingServer: !process.env.CI,
      timeout: 120000
    }
  ]
});
