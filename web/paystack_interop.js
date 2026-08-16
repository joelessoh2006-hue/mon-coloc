function paystackPopUp(publicKey, email, amount, ref, plan, currency, onClosed, callback) {
    if (typeof PaystackPop === 'undefined') {
        console.error("Paystack SDK not loaded yet");
        alert("Le service de paiement Paystack n'a pas pu être chargé. Vérifiez votre connexion ou désactivez votre bloqueur de publicité.");
        return null;
    }

    let handler = PaystackPop.setup({
        key: publicKey,
        email: email,
        amount: amount,
        ref: ref,
        plan: plan,
        currency: currency,
        onClose: function () {
            onClosed();
        },
        callback: function (response) {
            callback();
        },
    });

    return handler.openIframe();
}