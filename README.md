<p align="center">
  <img src="assets/logo-header.svg" alt="gix header logo">
</p>

<p align="center">
  <b>A modern GitHub TUI client with syntax highlighting and beautiful interface.</b>
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#keybindings">Keybindings</a>
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg">
  <img alt="Zig" src="https://img.shields.io/badge/zig-0.15.x-f7a41d.svg">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg">
</p>

---

## Key Features

### Notifications

View and manage your GitHub notifications in a beautiful TUI interface. Quickly see unread notifications, filter by repository, and mark items as read.

### Pull Requests

Browse pull requests with at-a-glance status indicators:
- Open, closed, and merged states with color coding
- Draft PR indicators
- Line additions/deletions stats
- Author and review information

### Issues

Track and manage issues across your repositories:
- State indicators (open/closed)
- Comment counts
- Label display
- Quick navigation

### Repositories

Explore your repositories with detailed information:
- Star and fork counts
- Primary language
- Public/private indicators
- Quick clone support

### Themes

Multiple built-in themes to match your terminal:
- Dark - Default dark theme
- Light - Clean light theme
- Nord - Popular Nord color palette

### Performance

Built with Zig for blazing-fast performance:
- Sub-100ms startup time
- Efficient memory usage
- Smart caching for API responses
- Minimal dependencies

---

## Installation

### Prerequisites

- [Zig](https://ziglang.org/) 0.15.0 or later
- [curl](https://curl.se/) (for HTTP requests)
- GitHub Personal Access Token

### Build from source

```bash
git clone https://github.com/yourusername/gix.git
cd gix
zig build -Doptimize=ReleaseFast
```

### Install to local bin

```bash
zig build install --prefix ~/.local
```

Or copy the binary manually:

```bash
cp zig-out/bin/gix ~/.local/bin/
```

---

## Usage

### Quick Start

1. Set your GitHub token:

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

2. Run gix:

```bash
gix
```

### Command Line Options

```
gix [OPTIONS]

Options:
  -v, --version    Show version information
  -h, --help       Show help message
  --setup          Run initial setup wizard
```

### Setup Wizard

Run the interactive setup to configure your token:

```bash
gix --setup
```

This will guide you through:
1. Entering your GitHub Personal Access Token
2. Saving configuration to `~/.config/gix/config.toml`

---

## Configuration

### Configuration File

gix looks for configuration at `~/.config/gix/config.toml`:

```toml
[auth]
token = "ghp_your_github_token"

[ui]
theme = "dark"           # dark, light, or nord
show_icons = true
page_size = 20

[cache]
enabled = true
ttl = 300                # Cache TTL in seconds
max_size = 104857600     # 100MB
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub Personal Access Token (overrides config file) |

### Creating a GitHub Token

1. Go to [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes:
   - `notifications` - Access notifications
   - `repo` - Access private repositories
   - `read:user` - Read user profile data
4. Copy the generated token

---

## Keybindings

### Global

| Key | Action |
|-----|--------|
| `q` | Quit |
| `1-5` | Switch views |
| `r` | Refresh current view |
| `?` | Show help |

### Navigation

| Key | Action |
|-----|--------|
| `↑` / `k` | Move up |
| `↓` / `j` | Move down |
| `PgUp` | Page up |
| `PgDn` | Page down |
| `Enter` | Select / Open |

### Views

| Key | View |
|-----|------|
| `1` | Dashboard |
| `2` | Notifications |
| `3` | Pull Requests |
| `4` | Issues |
| `5` | Repositories |

### View-Specific

Notifications:
| Key | Action |
|-----|--------|
| `m` | Mark as read |

Repositories:
| Key | Action |
|-----|--------|
| `/` | Search |
| `c` | Clone repository |

---

## Troubleshooting

### "GitHub token not found"

Make sure you've set the `GITHUB_TOKEN` environment variable or run `gix --setup`.

### "Rate limit exceeded"

GitHub API has rate limits. gix uses caching to minimize API calls. Wait a few minutes or check your rate limit status at https://api.github.com/rate_limit.

### Terminal display issues

- Ensure your terminal supports UTF-8
- Use a terminal with truecolor support for best results
- Try a different theme if colors look off

### curl errors

gix uses curl for HTTP requests. Make sure curl is installed:

```bash
# macOS (pre-installed)
curl --version

# Linux
sudo apt install curl  # Debian/Ubuntu
sudo dnf install curl  # Fedora
```

---

## Development

### Building

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Run tests
zig build test
```

### Project Structure

| Directory | Description |
|-----------|-------------|
| `src/app/` | Application lifecycle and state management |
| `src/domain/` | Core business logic and data models |
| `src/infrastructure/` | External services (GitHub API, storage) |
| `src/ui/` | Terminal UI components and rendering |
| `src/utils/` | Shared utilities (HTTP, logging, terminal) |

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.
