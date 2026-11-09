# Guide pas à pas — Durcissement d'un serveur Linux (P09)

Ce guide t'accompagne du début à la fin. Chaque étape te donne : **l'objectif**,
**où** lancer la commande, **la commande exacte**, **le résultat attendu**, et
**quoi faire si ça ne marche pas**.

> Termes anglais entre parenthèses : tu dois pouvoir les défendre en entretien.

---

## Avant de commencer : la machine

- VM dédiée **SRV-SEC01** (Ubuntu Server 24.04 LTS), clone de ta VM Ubuntu Server.
- **Pas** SRV-LNX01 (qui porte GLPI/Zabbix). On ne mélange pas.
- 2 vCPU, 2 Go de RAM.
- Carte 1 en **NAT** (VMnet8) pour installer les paquets.
- Carte 2 sur **LAB-NET** (VMnet2) en `192.168.10.30`.
- **Kali** (`192.168.10.66`) sert à l'étape 1.3.6.

### Règle d'or pendant tout le projet
Garde **toujours deux sessions ouvertes** quand tu touches à SSH ou PAM. Si une
se bloque, l'autre te sauve. Et fais un **snapshot** avant chaque étape risquée.

---

## Étape 0 — Préparer la VM et le dépôt

### 0.1 Cloner la VM (dans VMware Workstation)
1. VM Ubuntu Server éteinte → clic droit → **Manage → Clone**.
2. Type : **Full Clone** (clone complet, indépendant).
3. Nom : `SRV-SEC01`.
4. Dans **Settings → Network Adapter**, règle les deux cartes comme ci-dessus.

### 0.2 Snapshot de départ
Dans VMware : **VM → Snapshot → Take Snapshot**, nom `base-propre-JJ-MM`.

### 0.3 Récupérer le dépôt sur la VM
**Où :** terminal de SRV-SEC01.

```bash
# Mets à jour le système d'abord
sudo apt update && sudo apt upgrade -y

# Installe git si besoin
sudo apt install -y git

# Clone ton dépôt (une fois qu'il est sur GitHub) :
git clone https://github.com/tekteku/linux-hardening-security-lab.git
cd linux-hardening-security-lab
```

> Pour l'instant, si le dépôt n'est pas encore en ligne, tu peux copier le
> dossier dans la VM avec un dossier partagé VMware ou via `scp`.

### 0.4 État de départ (lecture seule)
**Où :** terminal de SRV-SEC01.

```bash
sudo bash scripts/00_prechecks.sh
```

**Résultat attendu :** un rapport dans `output/` qui liste l'OS, les comptes,
la config SSH actuelle, et quels outils de sécurité manquent. Rien n'est modifié.

### 0.5 Score Lynis AVANT (ton chiffre de départ)
**Où :** terminal de SRV-SEC01.

```bash
sudo apt install -y lynis
sudo lynis audit system | tee output/lynis_avant.txt
```

**Résultat attendu :** à la fin, une ligne `Hardening index : XX`. **Note ce
chiffre.** C'est ton « avant ». À la fin du projet, on relancera pour le « après ».

**Si ça ne marche pas :** si `lynis` n'est pas trouvé, installe-le via snap :
`sudo snap install lynis` ou télécharge-le depuis le site officiel.

---

## 1.3.1 — Sécuriser l'accès SSH

### Objectif
Fermer la porte d'entrée à distance : pas de root, pas de mot de passe, clé
uniquement, et seulement pour un groupe autorisé.

### Concepts (à défendre en entretien)
- **SSH (Secure Shell)** : administration à distance en ligne de commande.
- **Clé publique/privée (key-based auth)** : une paire de clés remplace le mot
  de passe. La clé privée reste sur ton PC, la clé publique sur le serveur.
- **Activation par socket (socket activation)** : sur Ubuntu 24.04, c'est
  `ssh.socket` (systemd) qui écoute, pas `ssh.service`. Important si tu changes
  le port.

### AVANT : crée ta clé SSH (sur ton PC Windows, PowerShell)
```powershell
# Sur ton PC, PAS dans la VM
ssh-keygen -t ed25519 -C "taher-lab"
# Copie la clé publique vers le serveur (remplace user et IP) :
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@192.168.10.30 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Teste que la clé marche AVANT de couper les mots de passe :**
```powershell
ssh user@192.168.10.30
```
Si tu entres sans qu'on te demande de mot de passe, la clé fonctionne. **Ne
continue pas tant que ce n'est pas le cas.**

### Snapshot
VMware → snapshot `avant-ssh-JJ-MM`.

### La commande
**Où :** terminal de SRV-SEC01. **Garde une 2ᵉ session SSH ouverte.**
```bash
sudo bash scripts/01_ssh_hardening.sh
```

### Résultat attendu
- Le script crée le groupe `sshusers`, t'y ajoute, installe la config, teste la
  syntaxe (`sshd -t`) et recharge SSH.
- **Preuve 1** (doit marcher) : `ssh user@192.168.10.30` → tu entres avec ta clé.
- **Preuve 2** (doit être refusée) :
  ```bash
  ssh -o PubkeyAuthentication=no user@192.168.10.30
  ```
  → `Permission denied`. C'est la preuve que le mot de passe est bien coupé.

### Si ça ne marche pas
- **Tu es bloqué dehors** : reviens à la 2ᵉ session ouverte, ou restaure le
  snapshot `avant-ssh-JJ-MM`.
- **`sshd -t` renvoie une erreur** : lis la ligne indiquée, c'est une faute de
  frappe dans le fichier. Corrige et relance.
- **Tu n'es pas dans sshusers** : `sudo usermod -aG sshusers <ton-user>`.

---

## 1.3.2 — Politique de mots de passe

### Objectif
Imposer des mots de passe longs et complexes, les faire expirer, et verrouiller
un compte après plusieurs échecs.

### Concepts
- **PAM (Pluggable Authentication Modules)** : la couche qui décide si une
  connexion est acceptée.
- **pam_pwquality** : vérifie la complexité quand on change de mot de passe.
- **Password aging** : durée de vie d'un mot de passe.
- **pam_faillock** : verrouille le compte après X échecs.

### ⚠️ DANGER
Une erreur dans PAM peut bloquer **toutes** les connexions.
1. Snapshot **obligatoire** : `avant-pam-JJ-MM`.
2. Ouvre une session root et **ne la ferme pas** : `sudo -i`.

### La commande
**Où :** terminal de SRV-SEC01 (en gardant le root ouvert à côté).
```bash
sudo bash scripts/02_password_policy.sh
```

### Résultat attendu
- La config de complexité et de verrouillage est installée.
- **Preuve 1 (complexité)** : crée un test et essaie un mot de passe faible :
  ```bash
  sudo useradd -m testweak
  sudo passwd testweak      # tape "password" → doit être REFUSÉ
  ```
- **Preuve 2 (verrouillage)** : essaie de te tromper 3 fois de suite sur un
  compte test, puis :
  ```bash
  faillock --user testweak   # montre les échecs et le verrouillage
  ```
- **Preuve 3 (expiration)** : `sudo chage -l <user>` montre la date d'expiration.

### Vérifier qu'une NOUVELLE connexion marche encore
Dans une **nouvelle** session, connecte-toi normalement. Si ça marche, tu peux
fermer la session root de secours. **Si ça ne marche pas, NE ferme pas le root**
et restaure le snapshot.

### Si ça ne marche pas
- **Plus personne ne peut se connecter** : via la session root ouverte, remets
  le fichier d'origine : `faillock --user <user> --reset`, puis vérifie
  `/etc/pam.d/common-auth`. En dernier recours, restaure le snapshot.
- **Débloquer un compte** : `sudo faillock --user <user> --reset`.

---

## 1.3.3 — Gérer et verrouiller les comptes

### Objectif
Faire le ménage : aucun compte sans mot de passe, aucun second root, les comptes
de service sans shell de connexion.

### Concepts
- **UID (User ID)** : les humains ont UID ≥ 1000, les comptes système < 1000.
- **UID 0** : c'est root. Tout autre compte à UID 0 = un second root caché, très
  dangereux.
- **Shell nologin** : un compte de service ne doit pas pouvoir ouvrir de session.
- **Account lifecycle** : arrivée (onboarding) et départ (offboarding).

### La commande (audit d'abord)
**Où :** terminal de SRV-SEC01.
```bash
sudo bash scripts/03_accounts.sh          # lecture seule, montre les problèmes
sudo bash scripts/03_accounts.sh --apply  # applique les corrections sûres
```

### Résultat attendu
- L'audit liste les comptes humains, cherche les UID 0 en trop, les mots de passe
  vides, et les comptes système avec un shell.
- `--apply` met un shell `nologin` sur les comptes système concernés, **sans
  jamais toucher ton compte ni root**.

### Si ça ne marche pas
- **Un compte légitime a perdu son shell** : remets-le avec
  `sudo usermod -s /bin/bash <user>`.

---

## 1.3.4 — Privilèges root limités (sudo)

### Objectif
Donner à un rôle « support » le droit de faire **seulement** quelques commandes,
rien de plus. C'est le **moindre privilège (least privilege)**.

### Concepts
- **sudo** : exécuter une commande en root, tracé dans `/var/log/auth.log`.
- **visudo** : le seul éditeur qui vérifie la syntaxe avant d'enregistrer. Une
  faute dans sudoers peut casser sudo.

### La commande
**Où :** terminal de SRV-SEC01.
```bash
sudo bash scripts/04_sudo.sh
```

### Résultat attendu
- Groupe `support` créé, règle installée et validée (`visudo -c`).
- **Preuve 1** : crée un utilisateur de test et montre ses droits :
  ```bash
  sudo useradd -m -s /bin/bash supuser
  sudo usermod -aG support supuser
  sudo -l -U supuser        # liste SEULEMENT les commandes autorisées
  ```
- **Preuve 2 (refus)** :
  ```bash
  su - supuser -c 'sudo systemctl restart cron'   # doit être REFUSÉ
  sudo tail /var/log/auth.log                       # le refus est tracé
  ```

### Si ça ne marche pas
- **sudo ne marche plus du tout** : via ta session root, supprime le fichier
  fautif : `rm /etc/sudoers.d/support`, puis relance le script.

---

## 1.3.5 — Limiter les ressources (déni de service local)

### Objectif
Empêcher un utilisateur de saturer la machine (ex. **fork bomb** : un processus
qui se duplique sans fin).

### Concepts
- **Déni de service local (local DoS)** : épuiser les ressources de la machine.
- **nproc / nofile / maxlogins** : nombre de processus / fichiers ouverts /
  sessions par utilisateur.

### La commande
**Où :** terminal de SRV-SEC01.
```bash
sudo bash scripts/05_limits.sh
```

### Résultat attendu
- Les limites sont installées dans `/etc/security/limits.d/`.
- Vérifie dans une session : `ulimit -a`.

### Le test de la fork bomb — SEULEMENT dans la VM, après snapshot
1. Snapshot `avant-limits-JJ-MM`.
2. Crée un utilisateur de test très limité :
   ```bash
   sudo useradd -m -s /bin/bash bombtest
   sudo usermod -aG testlimit bombtest   # groupe limité à 50 processus
   sudo passwd bombtest
   ```
3. Connecte-toi **en tant que bombtest** et lance la bombe :
   ```bash
   su - bombtest
   :(){ :|:& };:
   ```
4. **Résultat attendu** : la limite `nproc` bloque la multiplication. La machine
   reste utilisable depuis ta session admin. Ferme la session bombtest.

### Si ça ne marche pas
- **La machine rame vraiment** : restaure le snapshot `avant-limits-JJ-MM`. C'est
  exactement pourquoi on en a fait un.

---

## 1.3.6 — Auditer la robustesse des mots de passe (John the Ripper)

### Objectif
Jouer l'attaquant : prouver qu'un mot de passe faible se casse en secondes, et
qu'un mot de passe conforme à notre politique résiste.

### Concepts
- **Attaque par dictionnaire (dictionary attack)** : essayer une liste de mots
  de passe courants.
- **yescrypt** : l'algorithme de hachage par défaut d'Ubuntu 24.04 (marqueur
  `$y$` dans `/etc/shadow`). Volontairement lent à casser.

### ⚠️ Règles strictes
- **Uniquement sur Kali**, avec des comptes de **test** aux mots de passe inventés.
- Les hashes, `unshadowed`, `john.pot` et les résultats **ne vont JAMAIS dans le
  dépôt** (ils sont déjà dans `.gitignore`).

### La procédure
1. Sur SRV-SEC01, crée deux comptes test :
   ```bash
   sudo useradd -m faible && echo 'faible:password123' | sudo chpasswd
   sudo useradd -m fort   && echo 'fort:Tr0ub4dour&3xplorer!' | sudo chpasswd
   ```
2. Extrais les hashes (combine passwd + shadow) :
   ```bash
   sudo unshadow /etc/passwd /etc/shadow > /tmp/unshadowed.txt
   ```
3. Copie `/tmp/unshadowed.txt` sur **Kali** (via `scp`), puis sur Kali :
   ```bash
   john --wordlist=/usr/share/wordlists/rockyou.txt --format=crypt /tmp/unshadowed.txt
   john --show --format=crypt /tmp/unshadowed.txt
   ```

### Résultat attendu
- Le compte `faible` (`password123`) est **cassé** en quelques secondes.
- Le compte `fort` **résiste** (John ne le trouve pas dans le dictionnaire).
- **La preuve** : une capture d'écran **floutée** montrant « faible » cassé et
  « fort » non cassé. Pas de hash dans le dépôt.

### Si ça ne marche pas
- **John dit « No password hashes loaded »** : utilise `--format=crypt` (c'est le
  mode qui gère yescrypt sur la version de Kali).
- **rockyou.txt est compressé** : `sudo gunzip /usr/share/wordlists/rockyou.txt.gz`.

---

## 1.3.7 — Intégrité des fichiers avec AIDE

### Objectif
Détecter toute modification d'un fichier système.

### Concepts
- **AIDE (Advanced Intrusion Detection Environment)** : contrôle d'intégrité
  (file integrity monitoring, FIM). Il prend une empreinte de chaque fichier,
  puis compare.
- AIDE **détecte**, il ne **prévient pas**.

### La commande
**Où :** terminal de SRV-SEC01.
```bash
sudo bash scripts/07_aide.sh
```

### Résultat attendu (le test de détection)
```bash
# 1) Modifie un fichier volontairement
echo '# test change' | sudo tee -a /etc/hosts.allow
# 2) Lance le contrôle
sudo aide --check        # AIDE signale /etc/hosts.allow comme modifié
# 3) Accepte le changement légitime
sudo aideinit -y -f && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Si ça ne marche pas
- **aideinit est très long** : c'est normal (plusieurs minutes), il lit tout le
  système. Laisse finir.

---

## 1.3.8 — Détecter rootkits et virus

### Objectif
Chercher les rootkits connus et tester l'antivirus.

### Concepts
- **Rootkit** : programme caché qui donne un accès root discret.
- **rkhunter / chkrootkit** : cherchent les signatures de rootkits.
- **ClamAV** : antivirus libre.
- **EICAR** : fichier de test standard, inoffensif, reconnu par tous les AV.

### La commande
**Où :** terminal de SRV-SEC01.
```bash
sudo bash scripts/08_malware.sh
```

### Résultat attendu (test ClamAV)
```bash
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.com
clamscan /tmp/eicar.com     # doit afficher : Eicar-Signature FOUND
rm -f /tmp/eicar.com
```

### Si ça ne marche pas
- **rkhunter affiche des warnings** : ce sont souvent des **faux positifs
  (false positives)**. Lis chacun, ne panique pas. En entretien, dis que tu les
  vérifies un par un.
- **freshclam dit « locked »** : le service de mise à jour tourne déjà ; attends
  une minute et relance `clamscan`.

---

## 1.4 — Vérification globale

### Objectif
Un seul script qui repasse sur tout et affiche OK / KO.

```bash
sudo bash scripts/verify.sh
```
**Résultat attendu :** `RESULT: X OK, 0 KO`. Si une ligne est KO, retourne à
l'étape concernée.

### Score Lynis APRÈS (ton chiffre final)
```bash
sudo lynis audit system | tee output/lynis_apres.txt
```
Compare `Hardening index` avant/après. Note les deux dans le tableau du README.
**C'est ton chiffre pour le CV.**

---

## 1.5 — Défis bonus (optionnel)

```bash
sudo bash scripts/09_firewall_fail2ban.sh
```
- **ufw** : pare-feu, seul SSH ouvert.
- **fail2ban** : bannit une IP après trop d'échecs SSH.

Vérifie : `sudo ufw status verbose` et `sudo fail2ban-client status sshd`.

---

## 1.6 — Publier sur GitHub

### Checklist AVANT de publier
- [ ] `output/` ne contient aucun vrai résultat (il est git-ignoré, vérifie quand même)
- [ ] Aucune clé privée, aucun hash, aucun mot de passe dans les fichiers
- [ ] Les captures d'écran sont **floutées** (IP, noms d'utilisateur)
- [ ] `verify.sh` affiche 0 KO
- [ ] Le tableau de résultats du README est rempli (score Lynis avant/après)

### Les commandes Git
**Où :** terminal (ton PC ou la VM, là où est le dépôt).
```bash
git init
git add .
git commit -m "feat: initial hardening lab structure"
# crée le dépôt vide sur github.com/tekteku d'abord, puis :
git remote add origin git@github.com:tekteku/linux-hardening-security-lab.git
git branch -M main
git push -u origin main
```

> Fais des commits **petits et fréquents** (feat:, fix:, docs:, test:, chore:).
> Rends les scripts exécutables côté Git :
> `git update-index --chmod=+x scripts/*.sh`

### Vérifier la CI
Sur GitHub, onglet **Actions** : les deux jobs (ShellCheck, pytest) doivent être
**verts**. Si c'est rouge, clique sur le job pour voir l'erreur.

---

## Fin de séance — ce que tu diras en entretien

**Q1. Pourquoi couper l'authentification par mot de passe sur SSH ?**
Parce qu'un mot de passe peut être deviné par force brute. Une clé ed25519 est
pratiquement impossible à deviner. On réduit la surface d'attaque.

**Q2. Quelle est la différence entre AIDE et un antivirus ?**
AIDE surveille l'**intégrité** : il détecte qu'un fichier a changé. L'antivirus
cherche des **signatures** de logiciels malveillants connus. L'un détecte le
changement, l'autre identifie la menace. Les deux détectent, ne préviennent pas.

**Q3. C'est quoi le moindre privilège, et comment tu l'as appliqué ?**
Donner à chacun seulement les droits nécessaires. J'ai créé un groupe « support »
qui peut redémarrer SSH et lire les logs, mais rien d'autre. Un membre ne peut
pas devenir root. Si son compte est compromis, les dégâts sont limités.
