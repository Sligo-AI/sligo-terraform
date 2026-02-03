# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "sligo-jekyll-theme"
  spec.version       = "1.0.0"
  spec.authors       = ["Sligo AI"]
  spec.email         = ["support@sligo.ai"]

  spec.summary       = "Official Jekyll theme for Sligo AI documentation sites"
  spec.description   = "A modern, accessible Jekyll theme with dark mode, search, and documentation-focused layouts for Sligo Cloud Platform documentation."
  spec.homepage      = "https://github.com/Sligo-AI/sligo-jekyll-theme"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").select { |f| f.match(%r!^(assets|_layouts|_includes|_sass|LICENSE|README)!i) }

  spec.add_runtime_dependency "jekyll", ">= 3.9", "< 5.0"
  spec.add_runtime_dependency "jekyll-seo-tag", "~> 2.0"
  spec.add_runtime_dependency "jekyll-sitemap", "~> 1.4"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
