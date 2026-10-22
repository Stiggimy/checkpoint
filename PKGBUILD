# Maintainer: Magrid0 <Magrid0@proton.me>
#
# VCS package: builds the latest commit from the master branch. Rebuild the
# package to pick up new commits.

pkgname=checkpoint-git
pkgver=0.9.35
pkgrel=1
pkgdesc="Universal system snapshot manager for Snapper and Timeshift (git)"
arch=('any')
url="https://github.com/Stiggimy/checkpoint"
license=('unknown')
depends=('bash' 'coreutils' 'gawk' 'grep' 'sed' 'sudo' 'util-linux')
makedepends=('git')
optdepends=(
    'fzf: interactive configuration and deletion menus'
    'snapper: Snapper snapshot backend'
    'timeshift: Timeshift BTRFS and RSYNC backends'
    'libnotify: desktop notifications for failures and unattended runs'
    'glib2: close active notifications after a retry'
)
provides=('checkpoint')
conflicts=('checkpoint')
install="$pkgname.install"
source=("$pkgname::git+$url.git#branch=master")
sha256sums=('SKIP')

pkgver() {
    cd "$pkgname"
    local ver
    ver=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' checkpoint | head -n 1)
    printf '%s.r%s.g%s' "${ver:-0.0.0}" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    install -Dm755 "$pkgname/checkpoint" "$pkgdir/usr/bin/checkpoint"

    install -d "$pkgdir/usr/lib/checkpoint"
    install -m644 "$pkgname"/lib/*.sh "$pkgdir/usr/lib/checkpoint/"

    install -Dm644 "$pkgname/checkpoint.1" "$pkgdir/usr/share/man/man1/checkpoint.1"

    install -d "$pkgdir/usr/share/checkpoint"
    cp -a "$pkgname/catalog" "$pkgdir/usr/share/checkpoint/"

    install -Dm644 "$pkgname/README.md" "$pkgdir/usr/share/doc/checkpoint/README.md"
}
