// Configuration minimale : un site de docs, pas de blog, pas de page d'accueil
// separee. A poser sur un squelette cree par `npx create-docusaurus@latest`.
// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "VM IAAS seanergy",
  tagline: "Etat du parc, genere depuis OpenTofu",
  favicon: "img/favicon.ico",

  // PIEGE GitLab Pages : l'URL du site est https://<groupe>.gitlab.io/<projet>/
  // donc baseUrl doit contenir le nom du projet, sinon tous les liens cassent.
  url: process.env.CI_PAGES_URL
    ? new URL(process.env.CI_PAGES_URL).origin
    : "http://localhost:3000",
  baseUrl: process.env.CI_PROJECT_NAME ? `/${process.env.CI_PROJECT_NAME}/` : "/",

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",
  i18n: { defaultLocale: "fr", locales: ["fr"] },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: "/", // la doc est le site
          sidebarPath: "./sidebars.js",
          // Le crayon "Editer cette page" n'a pas de sens sur du genere.
          editUrl: undefined,
        },
        blog: false,
        theme: { customCss: "./src/css/custom.css" },
      }),
    ],
  ],

  themeConfig: {
    navbar: {
      title: "VM IAAS seanergy",
      items: [
        { to: "/etat", label: "Etat du parc", position: "left" },
        { to: "/conventions", label: "Conventions", position: "left" },
        {
          href: process.env.CI_PROJECT_URL ?? "#",
          label: "Depot",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      copyright:
        "Genere depuis grappes.yaml et l'etat OpenTofu. Ne pas editer les pages d'etat a la main.",
    },
  },
};

export default config;
