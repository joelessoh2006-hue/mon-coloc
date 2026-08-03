function paystackPopUp(publicKey, email, amount, ref, plan, currency, onClosed, callback) {
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