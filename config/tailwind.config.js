const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    "./node_modules/flowbite/**/*.js"
  ],
  theme: {
    extend: {
      colors: {
        "fm-bg":            "#F5F7FB",
        "fm-bg-elevated":   "#FFFFFF",
        "fm-bg-subtle":     "#EDF0F6",
        "fm-border":        "#E2E6EE",
        "fm-border-strong": "#CCD3DF",
        "fm-text":          "#111111",
        "fm-text-muted":    "#555B66",
        "fm-text-dim":      "#9099A8",
        "fm-accent":        "#0A84FF",
        "fm-accent-soft":   "#E6F1FF",
        "fm-accent-deep":   "#0066D6",
        "fm-accent-ring":   "rgba(10, 132, 255, 0.2)",
        "fm-danger":        "#FF3B30",
        "fm-danger-soft":   "#FFE5E3",
        "fm-success":       "#34C759",
        "fm-warning":       "#C77D0F"
      },
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },


  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
    require('flowbite/plugin')({
      datatables: true,
    }),
  ]
}
