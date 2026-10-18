# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's GammaAdjuster` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's GammaAdjuster

## Overview (JP)

ログインするたびに画面の明るさが標準に戻ってしまう場合の対処アドオンです。「明るさの調節」で
保存した明るさは残っているのに画面だけが標準に戻っている状態を検出し、ワールドに入ってすぐ、
保存してある明るさを適用し直すようゲームに依頼します。明るさの値そのものを指定することは
できません。明るさはこれまでどおり、ゲームの「明るさの調節」で決めてください。

## Overview (EN)

Works around the console game dropping your screen brightness back to the default at every
login. The brightness you saved in Calibrate Brightness is still stored; this add-on notices that
the screen is not at it and, as soon as you enter the world, asks the game to apply it again. It
cannot choose a brightness itself — set that in the game's own Calibrate Brightness screen, as
usual.

---

## Description (JP)

ログインのたびに明るさが標準（100）に戻ってしまう場合に、「明るさの調節」で保存した明るさを
復元するアドオンです。

■ 何が起きているか

ゲームは明るさを2か所に持っています。実際に画面に反映されている値と、プロファイルに保存
されている値です。ログイン直後、保存値は残っているのに、画面側だけが標準の100に戻って
いることがあります（このとき「明るさの調節」を開くと100と表示されます）。

■ このアドオンがすること

・ワールドに入ってすぐ、画面の明るさと、保存してある明るさを読み比べます。
・違っていた場合だけ、保存してある明るさを適用するようゲームに依頼します。ゲーム本体の
　オプション画面の「適用」ボタンと同じ処理です。
・ゲームが数秒後に標準の値へ戻す場合に備えて、1秒後・5秒後・15秒後にも確認します。
　自動で依頼するのは、1回のログインにつき最大3回までです。
・すでに一致している場合は何もしません。入れただけの状態は、入れていない状態と同じです。
・依頼の結果は、依頼前の保存値と比べて確かめます。保存してあった明るさが逆に上書き
　されてしまった場合は、成功とは扱わず、以後の自動の依頼を止めて、チャットで知らせます。

■ できないこと

・明るさの値を指定すること。コンソールでは、アドオンからの明るさの書き込みはゲームに
　無視されるため、スライダーなどで好きな値へ変更することはできません。明るさはこれまで
　どおり、ゲーム本来の「明るさの調節」で設定してください。このアドオンが戻すのは、そこで
　保存した値です。

■ 注意

・ログイン直後、このアドオンが復元する前にゲームの設定画面を開くと、ゲームが保存済みの
　明るさを、現在の（標準の）明るさで上書きしてしまうことがあります。上書きされた場合は、
　「明るさの調節」でもう一度設定してください。
・HDR使用時の動作は確認していません。ゲーム本体もHDR使用時はガンマの項目を表示しません。

■ 設定

設定 → アドオン設定 → PB's GammaAdjuster（LibHarvensAddonSettings が必要です）

　ログイン時に保存した明るさを復元する    オン／オフ（初期値はオン）
　保存した明るさを今すぐ復元する          ボタン

チャットコマンドでも操作できます。
　/pbgamma           画面の明るさと保存してある明るさ、ゲームの返答のログ
　/pbgamma resync    保存した明るさを今すぐ復元する
　/pbgamma on | off  ログイン時の復元をオン／オフ

画面が変わらない場合は、/pbgamma と入力し、表示された内容を知らせてください。

## Description (EN)

Restores the brightness you saved in Calibrate Brightness when the console game drops it back
to the default (100) at every login.

■ What is going on

The game keeps the brightness in two places: the value actually applied to the screen, and the
value stored in your profile. Right after a login the stored value can still be yours while the
screen alone has gone back to the default 100 (Calibrate Brightness shows 100 at that point).

■ What this add-on does

- As soon as you enter the world it compares the brightness on screen with the one you saved.
- Only if they differ, it asks the game to apply the saved one. That is the same thing the
  Apply button in the game's own options screen does.
- It looks again 1, 5 and 15 seconds later, in case the game puts its own value back during
  start-up. It asks at most three times per login.
- If they already match it does nothing. Installing it changes nothing until it is needed.
- The result is checked against the saved value as it was before the request. If the saved
  brightness was overwritten instead, that is not counted as success: the add-on stops asking
  for the rest of the session and tells you in chat.

■ What it cannot do

- Choose a brightness. On console the game ignores a brightness written by an add-on, so a
  slider that sets any value you like is not possible. Set the brightness in the game's own
  Calibrate Brightness screen, as before; this add-on brings that saved value back.

■ Notes

- If you open the game's settings right after a login, before this add-on has restored the
  brightness, the game can overwrite the saved brightness with the current (default) one. If that
  happens, set it again in Calibrate Brightness.
- Behaviour with HDR has not been checked. The game itself hides its gamma setting while HDR is
  on.

■ Settings

Settings → Add-On Settings → PB's GammaAdjuster (requires LibHarvensAddonSettings)

  Restore the saved brightness at login    on / off (on by default)
  Restore the saved brightness now         button

It can also be used from chat.
  /pbgamma           the brightness on screen and the saved one, plus a log of what the game answered
  /pbgamma resync    restore the saved brightness now
  /pbgamma on | off  turn the login restore on or off

If the screen does not change, type /pbgamma and send the lines it prints.
