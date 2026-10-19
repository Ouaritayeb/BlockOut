package com.blockout.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var endsAtMillis = 0L
    private lateinit var countdown: TextView
    private val countdownUpdate = object : Runnable {
        override fun run() {
            val remaining = endsAtMillis - System.currentTimeMillis()
            if (remaining <= 0L) {
                finish()
                return
            }
            val totalSeconds = remaining / 1000L
            val hours = totalSeconds / 3600L
            val minutes = (totalSeconds % 3600L) / 60L
            val seconds = totalSeconds % 60L
            countdown.text = if (hours > 0L) {
                "%02d:%02d:%02d left".format(hours, minutes, seconds)
            } else {
                "%02d:%02d left".format(minutes, seconds)
            }
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(18, 34, 28)
        window.navigationBarColor = Color.rgb(18, 34, 28)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        endsAtMillis = intent.getLongExtra(EXTRA_ENDS_AT, 0L)
        setContentView(createContent(intent.getStringExtra(EXTRA_APP_LABEL) ?: "This app"))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        endsAtMillis = intent.getLongExtra(EXTRA_ENDS_AT, 0L)
        countdownUpdate.run()
    }

    override fun onResume() {
        super.onResume()
        countdownUpdate.run()
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(countdownUpdate)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        returnToHome()
    }

    private fun createContent(appLabel: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(30), dp(32), dp(30), dp(32))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.rgb(18, 34, 28), Color.rgb(25, 49, 39))
            )
        }

        val emblem = TextView(this).apply {
            text = "FOCUS"
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(214, 245, 142))
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            background = rounded(Color.rgb(42, 65, 51), dp(24).toFloat())
        }
        root.addView(emblem, LinearLayout.LayoutParams(dp(78), dp(78)).apply {
            bottomMargin = dp(28)
        })

        root.addView(textView(
            text = "YOUR FOCUS SESSION",
            color = Color.rgb(214, 245, 142),
            size = 12f,
            bold = true,
            gravity = Gravity.CENTER
        ))

        root.addView(textView(
            text = "Stay with what\nmatters.",
            color = Color.WHITE,
            size = 34f,
            bold = true,
            gravity = Gravity.CENTER
        ).apply {
            setPadding(0, dp(13), 0, dp(12))
        })

        root.addView(textView(
            text = "$appLabel is paused until your timer ends.",
            color = Color.rgb(195, 210, 200),
            size = 15f,
            bold = false,
            gravity = Gravity.CENTER
        ))

        countdown = textView(
            text = "",
            color = Color.WHITE,
            size = 24f,
            bold = true,
            gravity = Gravity.CENTER
        ).apply {
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setPadding(0, dp(28), 0, dp(32))
        }
        root.addView(countdown)

        val homeButton = Button(this).apply {
            text = "Back to home"
            textSize = 15f
            isAllCaps = false
            setTextColor(Color.rgb(18, 34, 28))
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            background = rounded(Color.rgb(214, 245, 142), dp(17).toFloat())
            setOnClickListener { returnToHome() }
        }
        root.addView(homeButton, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(54)
        ))

        root.addView(textView(
            text = "You can end this session anytime in BlockOut.",
            color = Color.rgb(165, 184, 171),
            size = 12f,
            bold = false,
            gravity = Gravity.CENTER
        ).apply {
            setPadding(0, dp(18), 0, 0)
        })

        return root
    }

    private fun textView(
        text: String,
        color: Int,
        size: Float,
        bold: Boolean,
        gravity: Int
    ) = TextView(this).apply {
        this.text = text
        setTextColor(color)
        textSize = size
        this.gravity = gravity
        if (bold) typeface = Typeface.create("sans-serif", Typeface.BOLD)
    }

    private fun rounded(color: Int, radius: Float) =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun returnToHome() {
        val home = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(home)
        finish()
    }

    companion object {
        const val EXTRA_APP_LABEL = "blocked_app_label"
        const val EXTRA_ENDS_AT = "block_session_ends_at"
    }
}
