#!/bin/bash
set -e
echo ""; echo "[+] GENERATING NEW BIP32 SEED..."; echo ""
# Create Seed #
if [[ ! -e stest.bak ]]; then touch stest.bak; chown "$USER" stest.bak; chmod 0600 stest.bak; else
echo ""; echo "STRESS TEST BACKUP FILE EXISTS!"; echo ""; read -p "Overwrite? (y/no) " ow
if [ "$ow" = "no" ]; then echo ""; read -p "PRESS ENTER TO EXIT"; exit 0; fi; fi
s=$(./pybtctool random_electrum_seed | ./pybtctool -s slowsha | ./pybtctool -s changebase 16 256 | ./pybtctool -b changebase 256 16 | ./pybtctool -s bip32_master_key)
echo ""; echo "[+] YOUR SEED IS: "$s""; echo ""; read -p "PRESS ENTER TO CONTINUE"
echo -en "\nSEED: "$s"\n\n" > stest.bak
# Create First Privkey/Address And Backup#
priv=$(./pybtctool bip32_ckd "$s" 0 | ./pybtctool -s bip32_extract_key)
addr=$(./pybtctool privtoaddr "$priv")
echo -en "\nAddress 0: "$addr"\nPrivkey 0: "$priv"\n" >> stest.bak
echo ""; read -p "Will you be using tor for blockchain interaction? (y/no) " tor
if [[ "$tor" = "no" ]]; then pybtc="./pybtctool"; else
pybtc="torify ./pybtctool"; fi
echo ""; echo -en "[+] FIRST ADDRESS: "$addr"\n[+] FIRST PRIVKEY: "$priv""; echo ""
# Initial Funding #
echo -e "\nYOU SHOULD FUND THIS ADDRESS NOW.\nAFTER IT IS FUNDED PRESS ENTER."; read
sum=$($(echo -n "$pybtc") unspent "$addr" | ./pybtctool -j multiaccess value | ./pybtctool -j sum)
while [[ "$sum" -lt "1" ]]; do echo ""; echo "NO SATOSHIS IN THIS ADDRESS YET."; echo ""
echo -e "YOU SHOULD FUND THIS ADDRESS NOW.\nAFTER IT IS FUNDED PRESS ENTER."; read
sum=$($(echo -n "$pybtc") unspent "$addr" | ./pybtctool -j multiaccess value | ./pybtctool -j sum); done
echo ""; read -p "Set fee in satoshis (suggested 10000): " fee; pos=$(($sum / $fee))
echo ""; echo "[+] FUNDED: "$addr""; echo "[+] AVAILABLE SATOSHIS: "$sum""; echo "[+] TRANSACTIONS POSSIBLE: "$pos""
echo ""; read -p "Set number of seconds between transactions: " sec; while [[ -z "$sec" ]]; do echo ""
echo "YOU MUST ENTER A VALID NUMBER!"; echo ""; read -p "Set number of seconds between transactions: " sec; done
sec=$(($sec - 3)); totx=$(($pos * $sec)); echo ""; echo "[+] TOTAL TIME TO COMPLETE: "$totx" SECONDS"; echo ""
echo "ONCE YOU START THE SCRIPT IT WILL CONTINUALLY GENERATE NEW ADDRESSES USING THE SEED CREATED IN THE BEGINNING. SENDING ALL AVAILABLE SATOSHIS TO THE NEXT DETERMINISTIC ADDRESS SPENDING ONLY THE "$fee" SATOSHI FEE THAT YOU SET ON EACH TRANSACTION."; echo ""
echo "IN THE CASE THAT THERE IS A PROBLEM, YOUR SEED AND ALL ADDRESSES/PRIVATE KEYS WILL BE STORED IN "$PWD"/stest.bak."
echo ""; read -p "PRESS ENTER TO BEGIN STRESSING THE NETWORK."
# Begin Stressing #
while [[ "$sum" -gt "$fee" ]]; do ntot=$(($totx - $sec)); echo ""; echo "[+] STRESSING FINISHED IN APROX. "$ntot" SECONDS..."
i=$(cat stest.bak | grep -c "Privkey"); npriv=$(./pybtctool bip32_ckd "$s" "$i" | ./pybtctool -s bip32_extract_key)
naddr=$(./pybtctool privtoaddr "$npriv"); echo -en "\nAddress "$i": "$naddr"\nPrivkey "$i": "$npriv"\n" >> stest.bak
amt=$(expr $sum - $fee); echo "[+] SENDING "$amt" SATOSHIS TO "$naddr...""
stx=$($(echo -n "$pybtc") unspent "$addr" | ./pybtctool -j select "$sum" | ./pybtctool -j mktx "$naddr":"$amt" | ./pybtctool -s sign 0 "$priv"); $(echo -n "$pybtc") pushtx "$stx"; sleep "$sec"; priv="$npriv"; addr="$naddr"
sum=$($(echo -n "$pybtc") unspent "$addr" | ./pybtctool -j multiaccess value | ./pybtctool -j sum)
pos=$(($sum / $fee)); totx=$(($pos * $sec)); done
echo ""; echo "[+] OUT OF SATOSHIS!"; echo ""; read -p "PRESS ENTER TO QUIT"; exit 0
