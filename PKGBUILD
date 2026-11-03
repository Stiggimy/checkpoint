# Maintainer: Stiggimy <https://github.com/Stiggimy>
#
# VCS package: builds the latest commit from the master branch. Rebuild the
# package to pick up new commits.

pkgname=checkpoint-git
pkgver=0.11.5
pkgrel=1
pkgdesc="Universal system snapshot manager supporting Snapper and Timeshift with porcelain IPC (git)"
arch=('any')
url="https://github.com/Stiggimy/checkpoint"
license=('GPL-3.0-or-later')
depends=('bash' 'coreutils' 'findutils' 'gawk' 'grep' 'sed' 'sudo')
makedepends=('git')
optdepends=(
    'fzf: interactive menus and snapshot deletion browser'
    'snapper: Btrfs/Ext4 snapshot backend'
    'timeshift: Btrfs/Rsync snapshot backend'
    'advance: universal modular system update manager (https://github.com/Stiggimy/advance)'
    'libnotify: desktop notifications for failures and background updates'
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
    install -Dm644 "$pkgname/CHANGELOG.md" "$pkgdir/usr/share/checkpoint/CHANGELOG.md"

    install -Dm644 "$pkgname/README.md" "$pkgdir/usr/share/doc/checkpoint/README.md"
    install -Dm644 "$pkgname/CHANGELOG.md" "$pkgdir/usr/share/doc/checkpoint/CHANGELOG.md"
    install -Dm644 "$pkgname/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
