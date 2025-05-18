#!/bin/bash

# Przerywa skrypt, jeśli którekolwiek polecenie zakończy się błędem
set -e

# Aktualizacja systemu
echo ""
echo ">>> Aktualizowanie systemu..."
sudo pacman -Syu --noconfirm

# Instalacja yay
echo ""
echo ">>> Instalacja yay..."
# Upewnij się, że jesteś w katalogu domowym lub innym zapisywalnym miejscu przed klonowaniem
# cd ~ 
if ! command -v yay &> /dev/null; then
    echo "yay nie jest zainstalowany. Próba instalacji..."
    sudo pacman -S --needed --noconfirm git base-devel
    # Klonowanie do katalogu tymczasowego lub dedykowanego dla budowy
    if [ -d "yay-bin" ]; then
        echo "Katalog yay-bin już istnieje. Usuwanie i ponowne klonowanie..."
        rm -rf yay-bin
    fi
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm # --noconfirm dla makepkg może nie działać dla wszystkich promptów, ale -si powinno obsłużyć instalację
    cd .. # Wróć do poprzedniego katalogu
    # rm -rf yay-bin # Opcjonalnie: usuń katalog po instalacji
else
    echo "yay jest już zainstalowany."
fi


# Konfiguracja klucza dla asus-linux.org
echo ""
echo ">>> Konfiguracja klucza GPG dla repozytorium asus-linux.org..."
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
echo ">>> Klucz GPG dla asus-linux.org powinien być teraz zaimportowany i podpisany lokalnie."

# --- Początek sekcji dodawania repozytorium G14 ---

PACMAN_CONF_FILE="/etc/pacman.conf"
REPO_NAME_TAG="[g14]"
REPO_SERVER_LINE="Server = https://arch.asus-linux.org"
FULL_REPO_ENTRY="${REPO_NAME_TAG}\n${REPO_SERVER_LINE}" # \n dla nowej linii

echo "--------------------------------------------------"
echo "Konfiguracja repozytorium [g14] w ${PACMAN_CONF_FILE}"
echo "--------------------------------------------------"

if grep -Fxq "${REPO_NAME_TAG}" "${PACMAN_CONF_FILE}"; then
    echo "INFO: Repozytorium ${REPO_NAME_TAG} już istnieje w ${PACMAN_CONF_FILE}."
    # Sprawdzenie, czy linia Server jest poprawna
    if grep -A 1 -Fxq "${REPO_NAME_TAG}" "${PACMAN_CONF_FILE}" | grep -Fxq "^\s*${REPO_SERVER_LINE}"; then
        echo "INFO: Linia Server dla ${REPO_NAME_TAG} jest poprawna."
    else
        echo "OSTRZEŻENIE: Repozytorium ${REPO_NAME_TAG} istnieje, ale linia Server jest inna lub jej brakuje."
        echo "INFO: Rozważ ręczną weryfikację pliku ${PACMAN_CONF_FILE}."
        # Można dodać logikę do aktualizacji/naprawy, ale to bardziej złożone.
        # Na przykład, usuwając starą sekcję i dodając nową.
    fi
else
    echo "INFO: Dodawanie repozytorium ${REPO_NAME_TAG} na końcu pliku ${PACMAN_CONF_FILE}..."
    if [ -n "$(tail -c1 "${PACMAN_CONF_FILE}")" ]; then
        echo | sudo tee -a "${PACMAN_CONF_FILE}" > /dev/null
    fi
    printf "\n%b\n" "${FULL_REPO_ENTRY}" | sudo tee -a "${PACMAN_CONF_FILE}" > /dev/null
    echo "INFO: Repozytorium ${REPO_NAME_TAG} zostało dodane."
    echo "WAŻNE: Po dodaniu nowego repozytorium, należy zaktualizować bazę danych pakietów."
fi
echo "--------------------------------------------------"
# --- Koniec sekcji dodawania repozytorium G14 ---


# Ponowna synchronizacja baz danych pacman po dodaniu nowego repozytorium
echo ">>> Synchronizowanie baz danych pakietów (po dodaniu repo g14)..."
sudo pacman -Syu --noconfirm

echo ">>> Instalowanie pakietów specyficznych dla ASUS z repozytorium g14 oraz innych narzędzi..."
sudo pacman -S --needed --noconfirm asusctl power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service

sudo pacman -S --needed --noconfirm supergfxctl # switcheroo-control jest zwykle częścią supergfxctl lub alternatywą
# Sprawdź, czy switcheroo-control jest nadal potrzebne/zalecane z supergfxctl dla Twojego modelu
# Jeśli tak, odkomentuj:
# sudo pacman -S --needed --noconfirm switcheroo-control 
sudo systemctl enable --now supergfxd.service # Upewnij się, że nazwa usługi jest poprawna (np. supergfxd lub supergfxd.service)
# Jeśli używasz switcheroo-control:
# sudo systemctl enable --now switcheroo-control.service

sudo pacman -S --needed --noconfirm rog-control-center
sudo pacman -S --needed --noconfirm linux-g14 linux-g14-headers # --needed zapobiega ponownej instalacji
echo ">>> Generowanie konfiguracji GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg


# Instalacja ważnych programów z oficjalnych repozytoriów
echo ""
echo ">>> Instalowanie wybranych programów z oficjalnych repozytoriów (pacman)..."

PACKAGES_PACMAN=(
    ufw
    lib32-nvidia-utils # Upewnij się, że używasz sterowników NVIDIA
    gamemode
    lib32-gamemode
    steam
)

for pkg in "${PACKAGES_PACMAN[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        echo "Instalowanie $pkg za pomocą pacman..."
        sudo pacman -S --noconfirm --needed "$pkg"
    else
        echo "$pkg jest już zainstalowany (sprawdzone przez pacman)."
    fi
done


# Instalacja pakietów za pomocą yay
echo ""
echo ">>> Instalowanie wybranych programów za pomocą yay (AUR)..."

PACKAGES_YAY=(
    brave-bin
    ttf-ms-win11-auto
    discord_arch_electron
    vscodium-bin
    vscodium-bin-marketplace
)

if command -v yay &> /dev/null; then
    if [ ${#PACKAGES_YAY[@]} -gt 0 ]; then
        echo ">>> Synchronizowanie baz danych i aktualizacja pakietów systemowych (w tym yay) za pomocą yay..."
        # Aktualizuje system i wszystkie pakiety AUR, w tym yay, jeśli jest nowsza wersja.
        yay -Syu --needed --noconfirm --answeredit=none --answerdiff=none --removemake

        echo ">>> Instalowanie pakietów zdefiniowanych w PACKAGES_YAY..."
        for pkg_yay in "${PACKAGES_YAY[@]}"; do
            # Sprawdzamy, czy pakiet jest już zainstalowany
            if ! yay -Q "$pkg_yay" &>/dev/null; then
                echo "Instalowanie $pkg_yay za pomocą yay..."
                # Instalujemy pojedynczy pakiet
                # Flagi --answeredit=none i --answerdiff=none pomijają pytania o edycję PKGBUILDów
                # Flaga --removemake usuwa zależności budowania po zakończeniu
                yay -S --needed --noconfirm --answeredit=none --answerdiff=none --removemake "$pkg_yay"
            else
                echo "$pkg_yay jest już zainstalowany (sprawdzone przez yay)."
            fi
        done
        echo ">>> Zakończono instalację pakietów za pomocą yay."
    else
        echo "INFO: Brak zdefiniowanych pakietów w PACKAGES_YAY do instalacji."
        echo "INFO: Uruchamianie tylko aktualizacji systemu za pomocą yay."
        yay -Syu --needed --noconfirm --answeredit=none --answerdiff=none --removemake
    fi
else
    echo "BŁĄD: Polecenie yay nie zostało znalezione. Pakiety z AUR (${PACKAGES_YAY[*]}) nie zostaną zainstalowane."
    echo "Upewnij się, że yay został poprawnie zainstalowany na początku skryptu."
fi


echo "--------------------------------------------------"
echo "Modyfikowanie /etc/locale.gen i generowanie locale"
echo "--------------------------------------------------"

LOCALE_TO_ENABLE="en_US.UTF-8 UTF-8"
# Możesz dodać polskie locale, jeśli potrzebujesz:
# LOCALE_TO_ENABLE_PL="pl_PL.UTF-8 UTF-8" 
LOCALE_GEN_FILE="/etc/locale.gen"

# Funkcja do obsługi locale
configure_locale() {
    local locale_line="$1"
    local locale_file="$2"
    echo "INFO: Konfiguracja locale: ${locale_line}"
    if grep -q "^\s*${locale_line}" "${locale_file}"; then
        echo "INFO: Ustawienie regionalne '${locale_line}' jest już aktywne w ${locale_file}."
    elif grep -q "^\s*#\s*${locale_line}" "${locale_file}"; then
        echo "INFO: Odkomentowywanie ustawienia regionalnego '${locale_line}' w ${locale_file}..."
        sudo sed -i.bak "s|^\s*#\s*\(${locale_line}\)|\1|" "${locale_file}"
        echo "INFO: Linia została odkomentowana."
    else
        echo "OSTRZEŻENIE: Linia dla '${locale_line}' nie została znaleziona w ${locale_file}."
        echo "INFO: Dodawanie linii '${locale_line}' do ${locale_file}..."
        echo "${locale_line}" | sudo tee -a "${locale_file}" > /dev/null
    fi
}

configure_locale "${LOCALE_TO_ENABLE}" "${LOCALE_GEN_FILE}"
# configure_locale "${LOCALE_TO_ENABLE_PL}" "${LOCALE_GEN_FILE}" # Odkomentuj, jeśli dodałeś polskie locale

# Regeneracja ustawień regionalnych
echo "INFO: Generowanie ustawień regionalnych (locale-gen)..."
sudo locale-gen

echo "INFO: Konfiguracja locale zakończona."
echo "--------------------------------------------------"

echo "--------------------------------------------------"
echo "Dodawanie użytkownika do grupy gamemode..."
sudo gpasswd -a $USER gamemode
echo "INFO: Użytkownik $USER został dodany do grupy gamemode."

echo ""
echo "WSKAZÓWKA: Aby uruchomić grę na Steam z GameMode, kliknij prawym przyciskiem myszy na grę w Bibliotece, wybierz Właściwości..., a następnie w polu Opcje uruchamiania wpisz:"
echo "gamemoderun %command%"
echo ""



read -p "Czy chcesz zrestartować system teraz? (t/N): " REBOOT_NOW
if [[ "$REBOOT_NOW" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    echo "Restartowanie systemu..."
    sudo reboot
fi

echo ">>> Skrypt zakończył działanie."
exit 0
