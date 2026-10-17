@tool
extends EditorExportPlugin
## The phone's browser finishes Google sign-in at warfrontmandate://auth-callback#access_token=...
## This exported alias of the game activity receives that link; PlayerAuth reads it from the
## activity's intent (PlayerAuth.APP_RETURN). The game activity itself stays non-exported.
const MANIFEST:="""
        <activity-alias
            android:name=".GodotAuthReturn"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="warfrontmandate" android:host="auth-callback" />
            </intent-filter>
        </activity-alias>
"""
func _get_name() -> String:return "WarfrontAppLink"
func _supports_platform(platform: EditorExportPlatform) -> bool:return platform is EditorExportPlatformAndroid
func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform,_debug: bool) -> String:return MANIFEST
