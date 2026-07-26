const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch({ 
    headless: false, 
    slowMo: 1000 // Augmenté à 1s pour bien valider visuellement chaque champ
  });
  const page = await browser.newPage();

  try {
    console.log("🌍 Connexion à l'application Mon Coloc sur le port 51150...");
    await page.goto('http://localhost:51150/'); 
    await page.waitForLoadState('networkidle');

    // ==========================================
    // ETAPE 1 : INFORMATIONS PERSONNELLES
    // ==========================================
    console.log("📝 Remplissage de l'Étape 1...");
    
    // On cible le tout premier champ textuel trouvé sur la page (Index 0 = Nom)
    await page.locator('input[type="text"], input[value=""], [role="textbox"]').nth(0).click();
    await page.keyboard.type('Kouassi');

    // Index 1 = Prénom
    await page.locator('input[type="text"], input[value=""], [role="textbox"]').nth(1).click();
    await page.keyboard.type('Emmanuel');

    // Index 2 = Adresse email
    await page.locator('input[type="text"], input[value=""], [role="textbox"]').nth(2).click();
    await page.keyboard.type('emmanuel.kouassi@student.com');

    // Index 3 = Mot de passe (souvent un input de type "password" ou le 4ème champ)
    // On essaie d'abord de chercher un champ password, sinon on prend le 4ème champ
    const passwordField = page.locator('input[type="password"]');
    if (await passwordField.count() > 0) {
        await passwordField.click();
    } else {
        await page.locator('input[type="text"], [role="textbox"]').nth(3).click();
    }
    await page.keyboard.type('TestPass2026!');

    // Index 4 = Numéro de téléphone
    await page.locator('input[type="text"], [role="textbox"]').last().click();
    await page.keyboard.type('0708091011');

    // ==========================================
    // ETAPE 2 : CRITÈRES DE LOGEMENT
    // ==========================================
    console.log("🔍 Remplissage de l'Étape 2...");

    // Clic sur le choix de situation
    await page.getByText('Je cherche un logement').click();

    // Saisie du budget (En utilisant la méthode de frappe au clavier car Flutter camoufle le placeholder)
    await page.getByText('Montant en F CFA').click();
    await page.keyboard.type('85000');

    // Sélection des puces de quartier
    await page.getByText('Cocody', { exact: true }).click();
    await page.getByText('Riviera', { exact: true }).click();

    await page.screenshot({ path: 'rapports/etudiant_etape2_complete.png' });

    // Passage à l'étape 3
    await page.click('button:has-text("Suivant")');
    await page.waitForTimeout(1000);

    // ==========================================
    // ETAPE 3 : HABITUDES DE VIE & PROFIL
    // ==========================================
    console.log("🧬 Remplissage de l'Étape 3...");

    await page.getByText('Homme', { exact: true }).click();
    await page.getByText('Très propre', { exact: true }).click();

    await page.screenshot({ path: 'rapports/etudiant_etape3_final.png' });

    // Finalisation et envoi vers Firebase
    console.log("💾 Soumission du formulaire d'inscription...");
    await page.click('button:has-text("Terminer l\'inscription")');
    
    // Temps de latence pour laisser Firebase enregistrer le document
    } finally {
    await browser.close();
  }
})();