<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    public function updateAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => 'required|image|max:5120', // Max 5MB
        ]);

        $user = $request->user();

        if ($request->hasFile('avatar')) {
            // Delete old avatar if exists
            if ($user->avatar_url) {
                $oldFilename = basename($user->avatar_url);
                Storage::disk('public')->delete('avatars/' . $oldFilename);
            }

            $path = $request->file('avatar')->store('avatars', 'public');
            $user->avatar_url = url('/api/v1/avatar/' . basename($path));
            $user->save();
        }

        return response()->json(['avatar_url' => $user->avatar_url]);
    }

    /**
     * Permanently delete the account. Every user-owned table cascades on
     * delete, so tasks, habits, categories and transactions go with it.
     */
    public function destroy(Request $request): JsonResponse
    {
        $request->validate([
            'password' => 'required|current_password',
        ]);

        $user = $request->user();
        if ($user->avatar_url) {
            Storage::disk('public')->delete('avatars/' . basename($user->avatar_url));
        }
        $user->tokens()->delete();
        $user->delete();

        return response()->json(null, 204);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'preferences' => 'required|array',
        ]);

        $user = $request->user();
        
        // Merge with existing preferences
        $currentPreferences = $user->preferences ?? [];
        $newPreferences = array_merge($currentPreferences, $validated['preferences']);
        
        $user->preferences = $newPreferences;
        $user->save();

        return response()->json(['preferences' => $user->preferences]);
    }
}
