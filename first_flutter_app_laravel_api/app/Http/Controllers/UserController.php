<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
     public function createManager(Request $request)
    {
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => 'manager',
        ]);

        return response()->json([
            'message' => 'Manager created successfully',
            'user' => $user,
        ]);
    }

    public function usersWithLocations()
    {
        $users = User::with('location')
            ->where('role', 'user')
            ->get();

        return response()->json($users);
    }
}
