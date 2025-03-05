#!/bin/sh

# Этот скрипт лишь выкачивает бинарные файлы 7-zip, а затем делает из них установочные файлы для операционной системы OpenWrt. Автором 7-zip является https://sourceforge.net/u/ipavlov/profile/, а это лишь скрипт, который позволяет сделать ipk файлы для установки 7-zip на OpenWRT через системные пакеты. Официальный сайт 7z: https://www.7-zip.org/

dirInstall="bin" # путь установки приложения
serviceName="7zip" # имя службы
PackageName="7z" # имя пакета
IPKSource="7zSource" # папка, в которой будет создаваться файловая система ipk установочника

# Извлечение номера последней версии
getLatestRelease() {
  LatestRelease=$(curl -s https://sourceforge.net/projects/sevenzip/rss | sed -rn 's!.*/7-Zip/([0-9]+\.[0-9]+).*!\1!p' | head -1)
}

# Качает программу с интернета и извлекает нужные файлы из архива
DownloadVersion() {
  echo "Происходит загрузка "$PackageName" "$LatestRelease" для архитектуры "$architecture", подождите…"
  binName="${PackageName}$(echo "$LatestRelease" | tr -d '.')-linux-${architecture}.tar.xz"
  urlBin="https://7-zip.org/a/7z$(echo "$LatestRelease" | tr -d '.')-linux-${architecture}.tar.xz"
  mkdir -p "$IPKSource/$dirInstall" && curl -L --progress-bar -# -o "$IPKSource/$dirInstall/$binName" "$urlBin"
  tar -I xz -xvf $IPKSource/$dirInstall/$binName -C $IPKSource/$dirInstall 7zzs  > /dev/null && mv "$IPKSource/$dirInstall/7zzs" "$IPKSource/$dirInstall/7zz" && rm "$IPKSource/$dirInstall/$binName"
  # Извлекает и переименовывает файл 7zzs со статическими библиотеками, так как с динамичиескими не завелось. Разница в размере в худшую сторону, но работа в любой системе того стоит. Переименование файла выполняется из-за того, что справка в 7zzs выдёт работу с файлом 7zz. Другие файлы я не извлекаю, так как они занимают место и для корректной работы скрипта не нужны. Тем более, как я понял, вся нужная информация и так вшита в бинарнике. Ну и я не знаю где в OpenWrt харнятся файлы справок, но могу предположить, что в дирректории /usr/share/doc/название_программы/. Файлов license в установочнике тоже не встречал. Возможно, их можно хранить в корне установочника или в вышеназванной дирректории.
}

# Скачивание актуальной версии скрипта по сборке *.ipk приложения
UpdateScript() {
  echo "Происходит загрузка скрипта для сборки ipk пакета ipkg-build, подождите…"
  curl -Ls -O "https://github.com/openwrt/openwrt/raw/refs/heads/main/scripts/ipkg-build"
  chmod +x ./ipkg-build
  echo "Скрипт ipkg-build загружен"
}

# Удаление остаточных файлов от работы скприпта.
cleanUp() {
  rm -rf ipkg-build
}

# Удаление папки установки
cleanAll() {
  rm -rf "$IPKSource"
}

# Создаёт конфигурационные файлы, даёт разрешения, выполняет сборку приложения
compileIPK() {
    
# Создание папки для хранения файлов инициализации
mkdir -p "$IPKSource"/CONTROL/

cat << EOF > "$IPKSource"/CONTROL/control # Далее нужно внимательно проверить, верна ли информация, указанная ниже в файле control. Обязательно должны присутсвовать разделы Package, Version, Architecture, Maintainer, Description, хотя насчёт Description и Maintainer я не уверен, впрочем, может и ещё меньше можно оставить полей. Но лишняя информация вряд-ли повредит, особенно если она верно указана. Скрипт ipkg-build умеет заполнять Installed-Size автоматически. Так же можно использовать ещё в control файле ipk пункт Depends:, в котором можно указазать от каких других пакетов зависит данный пакет для своей работы. В поле Maintainer: так же после имени рекомендуется указывать <mail@mail.com>, который принадлежит Игорю Павлову разработчику 7-zip. SourceDateEpoch: как я понял, это в формате Unix time время крайнего измнения исходного кода.
Package: $PackageName
Version: $LatestRelease
Source: feeds/packages/utils/$PackageName
SourceName: $PackageName
License: LGPL-2.1+ WITH unRAR-restriction AND BSD-3-Clause
LicenseFiles: license.txt
Section: utils
SourceDateEpoch: 1732914000
Architecture: $PackageArchitecture
URL: https://www.7-zip.org/
Maintainer: Igor Pavlov
Installed-Size: 
Description: 7-Zip is a file archiver with a high compression ratio.
EOF

# curl -Ls -O "https://www.7-zip.org/license.txt" # Скачиваем файл лицензии, только непонятно нужно ли и если нужно, то куда его класть.

# $IPKSource/$dirInstall/7zzs # Выдача разрешений не имеет смысла, так как по умолчанию в архиве и так права уже выданы
  
# Сборка пакета
echo "Происходит сборка "$PackageName" для архитектуры "$PackageArchitecture", подождите…"
./ipkg-build "$IPKSource/"

if [ -f "$PackageName"_"$LatestRelease"_"$PackageArchitecture".ipk ]; then
		echo "Файл "$PWD"/"$PackageName"_"$LatestRelease"_"$PackageArchitecture".ipk создан, его можно устанавливать"
	else
		echo "Собрать установочный файл "$PackageName"_"$LatestRelease"_"$PackageArchitecture".ipk не удалось"
fi
}

# Основной алгоритм действия скрипта

UpdateScript
sed -i '/^echo "Packaged contents of \$pkg_dir into \$pkg_file"/d' ipkg-build

buildInstallerPackage() {
mkdir -p "$IPKSource"
getLatestRelease
DownloadVersion
for PackageArchitecture in $PackageArchitectures; do
compileIPK
done
cleanAll
}

# Сборка с разными архитектурами
# Список архитектур openwrt доступен по адресу: https://openwrt.org/docs/techref/instructionset/start Ещё можно изучить в разделе https://downloads.openwrt.org/releases/ файлы типа packages-*
# Файлы названия архитектуры на openwrt обычно с несколько другим названием, чем выдаёт $uname -m. Чтобы посмотреть архитектуру системы, которая используется для сверки ipk пакетов можно посмотреть в файе /etc/openwrt_release. Например, такой командой grep ARCH /etc/openwrt_release
# За поддержкой новых архитектур обращайтесь к автору на официальной странице https://sourceforge.net/projects/sevenzip/

PackageArchitectures="x86_64" architecture="x64"
buildInstallerPackage

PackageArchitectures="i386_geode i386_i486 i386_pentium4 i386_pentium-mmx" architecture="x86"
buildInstallerPackage

PackageArchitectures="aarch64_armv8-a aarch64_cortex-a53 aarch64_cortex-a72 aarch64_cortex-a76 aarch64_generic" architecture="arm64"
buildInstallerPackage

PackageArchitectures="arm_cortex-a7 arm_cortex-a7_neon-vfpv4 arm_cortex-a8_vfpv3 arm_cortex-a7_vfpv4 arm_cortex-a8_vfpv3 arm_cortex-a9 arm_cortex-a9_neon arm_cortex-a9_vfpv3 arm_cortex-a9_vfpv3-d16 arm_cortex-a15_neon-vfpv4 arm_cortex-a53_neon-vfpv4 arm_cortex-a5 arm_cortex-a5_vfpv4" architecture="arm" # Архитектура ARMv7-A, как я понял, но это не точно и нужны тесты
buildInstallerPackage

#PackageArchitectures="riscv64_riscv64" architecture="riscv64" # К сожалению, не видел сборок 7-zip под эту архитектуру, но надеюсь, что автор будет делать
#buildInstallerPackage

# Другие архитектуры, популярные, но, не особо приоритетные - это mips
# PackageArchitectures="MIPSEL_24KC MIPSEL_24KC_24KF MIPSEL_74KC MIPSEL_MIPS32 mipsel_mips32r2" architecture="mipsle"
# buildInstallerPackage
# PackageArchitectures="MIPS64_MIPS64 MIPS64_OCTEON MIPS64_OcteonPlus" architecture="mips64"
# buildInstallerPackage
# PackageArchitectures="MIPS_24KC MIPS_4KEC MIPS_MIPS32" architecture="mips"
# buildInstallerPackage
# PackageArchitectures="MIPS64EL_MIPS64" architecture="mips64le"
# buildInstallerPackage

# Удаление следов работы скрипта. Но сам скприпт и созданные файлы для разных архитектур остаются.
cleanUp

while true; do
	read -rp "Работа скрипта завершена. Удалить ли теперь и сам скрипт "$0"? [Д/н]: " answer
	case "$answer" in
		""|Д|д|Да|да|Y|y|Yes|yes)
			rm -rf "$0"
			exit 0
			;;
		Н|н|Нет|нет|N|n|No|no)
			exit 0
			;;
		*)
			echo "Неправильный ввод. Попробуйте еще раз."
			continue
			;;
		esac
done
