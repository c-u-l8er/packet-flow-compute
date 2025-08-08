// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      }
    },
  },
  plugins: [
    // Allows prefixing tailwind classes with LiveView classes to avoid conflicts,
    // e.g. <div class="phx-click-loading:animate-spin">
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", "& .phx-no-feedback"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", "& .phx-click-loading"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", "& .phx-submit-loading"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", "& .phx-change-loading"]))
  ]
}
