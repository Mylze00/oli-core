package com.example.oli_app

import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideNavigationBar()
    }

    // Réappliqué au retour dans l'appli (après un appel, le partage, un lecteur
    // vidéo plein écran…), car le système ou un plugin peut réafficher la barre.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideNavigationBar()
    }

    /**
     * Masque la barre de navigation Android (boutons ||| ◯ ‹ ou barre de gestes).
     * La barre d'état (heure, batterie) reste visible.
     * Un balayage depuis le bas de l'écran la fait réapparaître quelques
     * secondes, puis elle se masque à nouveau toute seule.
     */
    private fun hideNavigationBar() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.navigationBars())
    }
}
