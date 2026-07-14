package com.teamsb.tis_rms

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView
import android.app.Activity

class SplashActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        val logoImageView = findViewById<ImageView>(R.id.splash_logo)

        // Create a pulsing scale animation
        val scaleDown = ObjectAnimator.ofPropertyValuesHolder(
            logoImageView,
            PropertyValuesHolder.ofFloat("scaleX", 0.95f),
            PropertyValuesHolder.ofFloat("scaleY", 0.95f)
        )
        scaleDown.duration = 400
        scaleDown.repeatCount = 1
        scaleDown.repeatMode = ObjectAnimator.REVERSE
        scaleDown.interpolator = AccelerateDecelerateInterpolator()

        val scaleUp = ObjectAnimator.ofPropertyValuesHolder(
            logoImageView,
            PropertyValuesHolder.ofFloat("scaleX", 1.05f),
            PropertyValuesHolder.ofFloat("scaleY", 1.05f)
        )
        scaleUp.duration = 400
        scaleUp.repeatCount = 1
        scaleUp.repeatMode = ObjectAnimator.REVERSE
        scaleUp.interpolator = AccelerateDecelerateInterpolator()
        scaleUp.startDelay = 800

        scaleDown.start()
        scaleUp.start()

        // Proceed to MainActivity after animation finishes
        Handler(Looper.getMainLooper()).postDelayed({
            startActivity(Intent(this, MainActivity::class.java))
            finish()
            // Disable transition animation to make handoff smoother
            overridePendingTransition(0, 0)
        }, 1800)
    }
}
