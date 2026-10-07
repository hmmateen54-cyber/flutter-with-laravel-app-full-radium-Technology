<?php

namespace App\Http\Controllers;
use Illuminate\Support\Facades\Http;
use App\Models\UserLocation;
use Illuminate\Http\Request;

class UserLocationController extends Controller
{
    public function saveLocation(Request $request)
    {
        $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
        ]);


        $address = null;

        $response = Http::withHeaders([
            'User-Agent' => 'MyFlutterApp/1.0',
        ])->get('https://nominatim.openstreetmap.org/reverse', [
            'lat' => $request->latitude,
            'lon' => $request->longitude,
            'format' => 'json',
        ]);

        // if ($response->successful()) {
        //     $address = $response->json('display_name');
        // }

        if ($response->successful()) {
            $address = $response->json('display_name');
        } else {
            return response()->json([
                'status' => $response->status(),
                'response' => $response->body(),
            ], 500);
        }

        $location = UserLocation::updateOrCreate(
            [
                'user_id' => $request->user()->id,
            ],
            [
                'latitude' => $request->latitude,
                'longitude' => $request->longitude,
                'location_enabled' => true,
                'last_updated' => now(),
                'address' => $address,
                
            ]
        );

        return response()->json([
            'message' => 'Location saved successfully',
            'location' => $location,
        ]);
    }
}