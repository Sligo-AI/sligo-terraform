# Sligo Jekyll Theme

Official Jekyll theme for Sligo AI documentation sites. A modern, accessible documentation theme with dark mode, search, and responsive navigation.

![Sligo Jekyll Theme](assets/images/Full_Color_500x120.svg)

## Features

- 🎨 **Sligo Brand Design System** - Full implementation of Sligo's colors, typography, and components
- 🌗 **Dark Mode** - Automatic detection with manual toggle, persisted preference
- 🔍 **Built-in Search** - Client-side full-text search with keyboard navigation
- 📱 **Responsive** - Mobile-first design with collapsible sidebar
- 📖 **Documentation-focused** - Table of contents, code highlighting, callouts
- ⚡ **Fast** - No external dependencies, minimal JavaScript
- ♿ **Accessible** - WCAG 2.1 compliant with keyboard navigation
- 🔗 **GitHub Integration** - Edit on GitHub links, version selector

## Quick Start

### Option 1: Remote Theme (Recommended for GitHub Pages)

Add to your `_config.yml`:

```yaml
remote_theme: Sligo-AI/sligo-jekyll-theme
```

### Option 2: Gem-based Theme

Add to your `Gemfile`:

```ruby
gem "sligo-jekyll-theme", git: "https://github.com/Sligo-AI/sligo-jekyll-theme"
```

Then add to `_config.yml`:

```yaml
theme: sligo-jekyll-theme
```

## Configuration

Copy the theme's `_config.yml` settings to your site and customize:

```yaml
# Site Settings
title: "Your Documentation Title"
description: "Your site description"
baseurl: "/your-repo-name"  # for GitHub Pages project sites
url: "https://your-org.github.io"

# Theme Settings
theme_settings:
  # Logos (place in assets/images/)
  logo_light: "Full_Color_500x120.svg"
  logo_dark: "Rev_Color_500x120.svg"
  logo_mark_light: "Mark-Full_Color_150x150.svg"
  logo_mark_dark: "Mark-Full_Color-Dark_Mode_150x150.svg"
  
  # Features
  dark_mode: true
  search: true
  version_selector: true
  edit_on_github: true
  copy_code_button: true
  toc: true
  
  # Repository (for edit links)
  github_repo: "Your-Org/your-repo"
  github_branch: "main"
  docs_path: ""  # e.g., "docs/" if docs are in a subfolder
  
  # Version selector
  current_version: "1.0.0"
  versions:
    - label: "1.0.0"
      url: "/"
    - label: "0.9.0"
      url: "/v0.9.0/"
  
  # Header links
  header_links:
    - label: "GitHub"
      url: "https://github.com/Your-Org/your-repo"
      icon: "github"
    - label: "Support"
      url: "mailto:support@your-domain.com"
      icon: "mail"
  
  # Footer
  footer:
    copyright: "Your Company"
    links:
      - label: "Website"
        url: "https://your-domain.com"
      - label: "Privacy"
        url: "https://your-domain.com/privacy"

# Navigation structure
navigation:
  - title: "Getting Started"
    items:
      - title: "Overview"
        url: "/"
      - title: "Quick Start"
        url: "/quick-start/"
      - title: "Prerequisites"
        url: "/prerequisites/"
  - title: "Guides"
    items:
      - title: "Installation"
        url: "/installation/"
        badge: "Updated"
        badge_type: "new"
      - title: "Configuration"
        url: "/configuration/"
```

## Layouts

### `default`
Base layout with header, sidebar, and footer.

### `page`
Standard documentation page with optional table of contents.

```yaml
---
layout: page
title: "Page Title"
description: "Brief description for SEO"
toc: true  # Enable/disable table of contents (default: true)
---
```

### `doc`
Alias for `page`, useful for organizing docs in a collection.

### `home`
Landing page layout with hero section and feature cards.

```yaml
---
layout: home
title: "Welcome"
description: "Getting started with our platform"
hero_actions:
  - label: "Get Started"
    url: "/quick-start/"
    style: "primary"
    icon: true
  - label: "View on GitHub"
    url: "https://github.com/your-repo"
    style: "outline"
features:
  - title: "Easy Setup"
    description: "Get running in minutes with our quick start guide."
    icon: "rocket"
  - title: "Fully Documented"
    description: "Comprehensive guides and API reference."
    icon: "book"
---
```

## Components

### Callouts

Use callouts to highlight important information:

```markdown
<div class="callout callout--info">
  <div class="callout-content">
    <div class="callout-title">Note</div>
    This is an informational callout.
  </div>
</div>
```

Available types: `callout--info`, `callout--tip`, `callout--warning`, `callout--error`, `callout--success`

### Code Blocks

Syntax highlighting is automatic. Specify the language:

````markdown
```terraform
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}
```
````

Supported languages include: `terraform`, `hcl`, `yaml`, `json`, `bash`, `python`, `javascript`, and more.

### Tables

Tables are automatically wrapped for horizontal scrolling on mobile:

```markdown
| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region  | `us-east-1` |
| `name`   | Cluster name | Required |
```

### Buttons

```html
<a href="/quick-start/" class="btn btn--primary btn--lg">Get Started</a>
<a href="/docs/" class="btn btn--outline">Documentation</a>
```

## Customization

### Custom CSS

Add custom styles by creating `assets/css/custom.scss`:

```scss
---
---

// Override variables
$color-primary: #your-color;

// Import theme
@import "main";

// Add custom styles
.your-class {
  // styles
}
```

### Custom JavaScript

Add custom scripts by creating `assets/js/custom.js` and including it in your layout.

## File Structure

```
your-site/
├── _config.yml
├── index.md
├── assets/
│   └── images/
│       ├── Full_Color_500x120.svg
│       ├── Rev_Color_500x120.svg
│       ├── Mark-Full_Color_150x150.svg
│       └── Mark-Full_Color-Dark_Mode_150x150.svg
├── quick-start.md
├── installation.md
└── ...
```

## Search

Search is powered by a client-side JSON index. The `search.json` file is automatically generated during build.

**Keyboard shortcuts:**
- `Cmd/Ctrl + K` - Open search
- `↑ ↓` - Navigate results
- `Enter` - Select result
- `Esc` - Close search

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `bundle exec jekyll serve`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/Sligo-AI/sligo-jekyll-theme/issues)
- **Email**: support@sligo.ai

---

Built with ❤️ by [Sligo AI](https://sligo.ai)
