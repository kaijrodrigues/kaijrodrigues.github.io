# kaijrodrigues.github.io

Personal portfolio site for Kai Rodrigues — market research, UX research, and
quantitative research projects.

Live at: https://kaijrodrigues.github.io

## Structure

```
.
├── index.html              About + project index (homepage)
├── assets/
│   ├── style.css            Site-wide styles
│   ├── resume.pdf            ← replace with your actual résumé
│   └── images/                Project chart/screenshot images
└── projects/
    ├── project1.html         Project detail page template
    ├── project2.html
    └── project3.html
```

## Adding a new project

1. Copy `projects/project1.html` to `projects/your-project-slug.html`.
2. Update the title, tags, Question / Method / Key Finding sections, and the
   GitHub repo link at the bottom.
3. Drop any chart images into `assets/images/` and update the `<img src>` path.
4. Add a new `<li class="index-row">` entry to the project index in `index.html`,
   linking to your new page.
5. Update the `prev-next` links on adjacent project pages to keep the chain intact.

## Adding R / Quarto project pages

Render `.qmd` or `.Rmd` files to static HTML and drop the output into
`projects/`, or embed individual chart images into a page that follows this
site's template so it matches the rest of the portfolio visually.

## Local preview

No build step required — open `index.html` directly in a browser, or run:

```
python3 -m http.server 8000
```

and visit `http://localhost:8000`.
