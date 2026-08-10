# Appeal — «Violation of Play Console Requirements» (organization account)

Bu matn Play Console → **Submit an appeal** formasiga nusxa olinadi. Ingliz tilida —
sharhlovchi shu tilda o'qiydi. Kvadrat qavsdagi joylarni to'ldiring va qavslarni o'chiring.

> Avval PLAY-STORE.md 8-bo'limidagi deklaratsiyalarni tuzatib, qayta sharhga yuboring.
> Appeal — faqat tuzatilgandan **keyin ham** rad etilsa.

---

## Appeal matni

```
App name: Intellect Student
Package name: uz.intellectcrm.student

We believe this enforcement was applied in error and respectfully ask you to
reconsider.

WHAT THE APP IS

Intellect Student is a private-account companion app for students enrolled at
Intellect Kokand, a privately owned tutoring center in Kokand, Uzbekistan. It is
distributed only to that center's own enrolled students, who sign in with
credentials issued by the center. There is no public sign-up. The app shows a
student their own attendance records, grades, online tests, certificates, and
account statement, and lets them message the center's administration.

WHY NONE OF THE FOUR RESTRICTED CATEGORIES APPLY

1. Financial products and services — NOT APPLICABLE.
   The app does not process payments, does not accept or store card or bank
   details, does not integrate any payment processor, and does not move money in
   any direction. It contains no lending, investment, trading, cryptocurrency, or
   banking functionality. The "Payments" screen is a read-only statement: the
   tutoring center enters tuition charges and received payments into its own
   internal CRM, and the app displays that ledger to the student, exactly as a
   printed invoice would. Every value is server-rendered text; there are no
   transactional controls in the app at all.

   In App content → Financial features we have declared "My app doesn't provide
   any financial features," which accurately reflects the app.

2. Health apps — NOT APPLICABLE.
   The app collects, stores, and displays no health, medical, fitness, or human
   subjects research data of any kind. It requests no health-related permissions
   and integrates no health APIs or SDKs.

3. VPN — NOT APPLICABLE.
   The app does not use the VpnService class and requests no VPN-related
   permission. It communicates only with its own backend at
   https://crm.intellectschool.uz over HTTPS.

4. Government apps — NOT APPLICABLE.
   Intellect Kokand is a private commercial tutoring business. It is not a
   government agency, is not operated by one, and the app was not developed by or
   on behalf of any government body. No public authority commissioned, funds, or
   endorses this app.

APP CATEGORY

The app is published under the Education category and is tagged Education /
Study tools / Schools, which matches its functionality.

WHAT WE HAVE DONE

We have reviewed every App content declaration and confirmed that none of the
organization-only categories is selected, and that the store category is
Education. If a declaration on our side previously triggered this requirement, it
was a misunderstanding on our part of what counts as a "financial feature," and it
has been corrected.

We would be grateful if you could confirm which specific declaration or category
triggered this enforcement, so we can correct it precisely. A test student account
is provided under App access for full review of the app.

Thank you for your time.

[Ismingiz]
[Aloqa e-pochtasi]
```

---

## Agar Google javobida "the declaration is correct, you still need an organization account" desa

Unda ikki yo'l qoladi:

1. **Tashkilot hisobiga o'tkazish** — o'quv markazining yuridik shaxsi nomiga yangi
   Play developer hisobi ochiladi (D-U-N-S raqami talab qilinadi, olish 1-4 hafta,
   bepul), so'ng Play Console → **Setup → App transfer** orqali ilova o'tkaziladi.
   Foydalanuvchilar, sharhlar va imzo kaliti saqlanadi.
2. **Sababni yo'q qilish** — «To'lovlar» ekranini olib tashlab, faqat ta'lim
   funksiyalari bilan chiqarish. Bu ilova qiymatini kamaytiradi, shu sabab faqat
   1-yo'l ishlamasa ko'riladi.

D-U-N-S raqami: https://developer.google.com/apps/duns-lookup — mavjudligini avval
shu yerdan tekshiring, ko'p yuridik shaxslarda u allaqachon bor.
