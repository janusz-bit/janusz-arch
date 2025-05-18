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
sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si


# asus-linux.org...
echo ""
echo ">>> asus-linux.org..."
pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35

# --- Początek sekcji dodawania repozytorium G14 ---

PACMAN_CONF_FILE="/etc/pacman.conf"
REPO_NAME_TAG="[g14]"
REPO_SERVER_LINE="Server = https://arch.asus-linux.org"
FULL_REPO_ENTRY="${REPO_NAME_TAG}\n${REPO_SERVER_LINE}" # \n dla nowej linii

echo "--------------------------------------------------"
echo "Konfiguracja repozytorium [g14] w ${PACMAN_CONF_FILE}"
echo "--------------------------------------------------"

# Sprawdzenie, czy repozytorium [g14] już istnieje w pliku pacman.conf
# Używamy grep -Fxq:
# -F: traktuje wzorzec jako stały ciąg znaków (nie wyrażenie regularne)
# -x: dopasowuje całą linię
# -q: tryb cichy (nie wyświetla dopasowań, tylko zwraca kod wyjścia)
if grep -Fxq "${REPO_NAME_TAG}" "${PACMAN_CONF_FILE}"; then
    echo "INFO: Repozytorium ${REPO_NAME_TAG} już istnieje w ${PACMAN_CONF_FILE}."
    # Opcjonalnie: możesz dodać sprawdzanie, czy linia Server jest poprawna,
    # i ewentualnie ją zaktualizować, ale to bardziej skomplikowane.
    # Na przykład, sprawdzając czy poniższa linia istnieje PO linii [g14]:
    # if grep -A 1 -Fxq "${REPO_NAME_TAG}" "${PACMAN_CONF_FILE}" | grep -Fxq "^\s*${REPO_SERVER_LINE}"; then
    # echo "INFO: Linia Server dla ${REPO_NAME_TAG} wydaje się być poprawna."
    # else
    # echo "OSTRZEŻENIE: Repozytorium ${REPO_NAME_TAG} istnieje, ale linia Server jest inna lub jej brakuje."
    # echo "INFO: Rozważ ręczną weryfikację pliku ${PACMAN_CONF_FILE}."
    # fi
else
    echo "INFO: Dodawanie repozytorium ${REPO_NAME_TAG} na końcu pliku ${PACMAN_CONF_FILE}..."
    # Dodajemy wpis na końcu pliku /etc/pacman.conf
    # Używamy printf dla lepszej kontroli nad formatowaniem i nowymi liniami.
    # %b w printf pozwala na interpretację sekwencji ucieczki jak \n.
    # tee -a : dołącza do pliku (append) i wymaga sudo do zapisu w /etc/pacman.conf
    # > /dev/null przekierowuje standardowe wyjście tee (które jest kopią wejścia) do kosza.
    
    # Najpierw upewnijmy się, że jest nowa linia na końcu pliku, jeśli jej nie ma
    # (chociaż pacman jest zwykle tolerancyjny)
    if [ -n "$(tail -c1 "${PACMAN_CONF_FILE}")" ]; then
        # Jeśli ostatni znak nie jest nową linią, dodaj ją
        echo | sudo tee -a "${PACMAN_CONF_FILE}" > /dev/null
    fi
    
    printf "%b\n" "${FULL_REPO_ENTRY}" | sudo tee -a "${PACMAN_CONF_FILE}" > /dev/null
    echo "INFO: Repozytorium ${REPO_NAME_TAG} zostało dodane."
    echo "WAŻNE: Po dodaniu nowego repozytorium, należy zaktualizować bazę danych pakietów."
    echo "Można to zrobić później za pomocą 'sudo pacman -Syu' lub 'yay -Syu'."
fi

echo "--------------------------------------------------"
# --- Koniec sekcji dodawania repozytorium G14 ---


pacman -Suy
pacman -S asusctl power-profiles-daemon --noconfirm
systemctl enable --now power-profiles-daemon.service
pacman -S supergfxctl switcheroo-control --noconfirm
systemctl enable --now supergfxd
systemctl enable --now switcheroo-control
pacman -S rog-control-center --noconfirm
pacman -Sy linux-g14 linux-g14-headers --noconfirm
grub-mkconfig -o /boot/grub/grub.cfg


# Instalacja ważnych programów
echo ""
echo ">>> Instalowanie wybranych programów..."

PACKAGES_PACMAN=(
    ufw
    lib32-nvidia-utils
    gamemode
    lib32-gamemode
)

for pkg in "${PACKAGES_PACMAN[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        echo "Instalowanie $pkg..."
        sudo pacman -S --noconfirm --needed "$pkg"
    else
        echo "$pkg jest już zainstalowany."
    fi
done



PACKAGES_YAY=(
    brave-bin
    ttf-ms-win11-auto
    discord_arch_electron
)

# # Aktualizacja systemu i instalacja pakietów za pomocą yay
# echo ""
# echo ">>> Aktualizowanie systemu i instalowanie wybranych pakietów za pomocą yay..."
# # `--answeredit=none --answerdiff=none` są przydatne do pomijania pytań o edycję PKGBUILDów przy aktualizacjach
# # `--removemake` usuwa zależności potrzebne tylko do budowy po zakończeniu
# # `--sudoloop` utrzymuje pętlę sudo, aby nie trzeba było wpisywać hasła wielokrotnie (używaj ostrożnie)
# if [ ${#PACKAGES_YAY[@]} -gt 0 ]; then
#     yay -Syu --needed --noconfirm --answeredit=none --answerdiff=none --removemake "${PACKAGES_TO_INSTALL[@]}"
# else
#     echo "Brak zdefiniowanych pakietów do instalacji za pomocą yay. Aktualizuję tylko system."
#     yay -Syu --needed --noconfirm --answeredit=none --answerdiff=none
# fi


for pkg in "${PACKAGES_YAY[@]}"; do
    if ! yay -Q "$pkg" &>/dev/null; then
        echo "Instalowanie $pkg..."
        sudo yay -S --noconfirm --needed --answeredit=none --answerdiff=none --removemake "$pkg"
    else
        echo "$pkg jest już zainstalowany."
    fi
done






echo "--------------------------------------------------"
echo "Modyfikowanie /etc/locale.gen i generowanie locale"
echo "--------------------------------------------------"

LOCALE_TO_ENABLE="en_US.UTF-8 UTF-8"
LOCALE_GEN_FILE="/etc/locale.gen"

# Sprawdź, czy linia jest już odkomentowana
# Używamy grep -q (quiet) i sprawdzamy kod wyjścia
# ^\s* oznacza początek linii z opcjonalnymi białymi znakami
if grep -q "^\s*${LOCALE_TO_ENABLE}" "${LOCALE_GEN_FILE}"; then
    echo "INFO: Ustawienie regionalne '${LOCALE_TO_ENABLE}' jest już aktywne w ${LOCALE_GEN_FILE}."
# Sprawdź, czy linia istnieje, ale jest zakomentowana
elif grep -q "^\s*#\s*${LOCALE_TO_ENABLE}" "${LOCALE_GEN_FILE}"; then
    echo "INFO: Odkomentowywanie ustawienia regionalnego '${LOCALE_TO_ENABLE}' w ${LOCALE_GEN_FILE}..."
    # Używamy sudo, ponieważ /etc/locale.gen wymaga uprawnień roota
    # sed -i.bak tworzy kopię zapasową oryginalnego pliku z rozszerzeniem .bak
    # s|PATTERN|REPLACEMENT| - użyliśmy | jako separatora, aby uniknąć problemów ze znakami / w PATTERN
    # \s* dopasowuje zero lub więcej białych znaków
    # \(...\) to grupa przechwytująca, \1 to odwołanie do tej grupy
    sudo sed -i.bak "s|^\s*#\s*\(${LOCALE_TO_ENABLE}\)|\1|" "${LOCALE_GEN_FILE}"
    echo "INFO: Linia została odkomentowana."
else
    echo "OSTRZEŻENIE: Linia dla '${LOCALE_TO_ENABLE}' (zakomentowana lub nie) nie została znaleziona w ${LOCALE_GEN_FILE}."
    echo "INFO: Może być konieczne ręczne dodanie lub weryfikacja pliku ${LOCALE_GEN_FILE}."
    # Opcjonalnie: można dodać linię, jeśli jej w ogóle nie ma:
    # echo "INFO: Dodawanie linii '${LOCALE_TO_ENABLE}' do ${LOCALE_GEN_FILE}..."
    # echo "${LOCALE_TO_ENABLE}" | sudo tee -a "${LOCALE_GEN_FILE}" > /dev/null
    # Jednak dla locale.gen zwykle wystarczy odkomentować istniejącą.
fi

# Regeneracja ustawień regionalnych
echo "INFO: Generowanie ustawień regionalnych (locale-gen)..."
sudo locale-gen

echo "INFO: Konfiguracja locale zakończona."
echo "--------------------------------------------------"




echo ""
echo "To make Steam start a game with GameMode, right click the game in the Library, select Properties..., then in the Launch Options text box enter:\n\ngamemoderun %command%\nUSE: gpasswd -a user group"


read -p "Czy chcesz zrestartować system teraz? (t/N): " REBOOT_NOW
if [[ "$REBOOT_NOW" =~ ^([tT][aA][kK]|[tT])$ ]]; then
    echo "Restartowanie systemu..."
    sudo reboot
fi

exit 0