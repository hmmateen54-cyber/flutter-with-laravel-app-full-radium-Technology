<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\BrandController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\UserLocationController;


// Logged-in User Info

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');


// Authentication

Route::post('/register', [AuthController::class, 'register']);

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->post(
    '/logout',
    [AuthController::class, 'logout']
);

// Protected APIs

Route::middleware('auth:sanctum')->group(function () {


    // ==========================================
    // USER + MANAGER + ADMIN
    // READ ONLY
    // ==========================================

    // Categories - GET
    Route::get(
        '/categories',
        [CategoryController::class, 'index']
    );

    // Brands - GET
    Route::get(
        '/brands',
        [BrandController::class, 'index']
    );

    // Products - GET by brand
    Route::get(
        '/products',
        [ProductController::class, 'index']
    );

    // All Products
    Route::get(
        '/all-products',
        [ProductController::class, 'allProducts']
    );

    Route::post(
    '/orders',
    [OrderController::class, 'store']
    );

    Route::get(
        '/my-orders',
        [OrderController::class, 'myOrders']
    );

    Route::post(
    '/location',
    [UserLocationController::class, 'saveLocation']
    );

    // ==========================================
    // ADMIN + MANAGER
    // CREATE / UPDATE / DELETE
    // ==========================================

    Route::middleware('admin.manager')->group(function () {


        // -------------------------
        // Categories
        // -------------------------

        Route::post(
            '/categories',
            [CategoryController::class, 'store']
        );

        Route::put(
            '/categories/{id}',
            [CategoryController::class, 'update']
        );

        Route::delete(
            '/categories/{id}',
            [CategoryController::class, 'destroy']
        );

        Route::get(
        '/orders',
        [OrderController::class, 'allOrders']
        );

        Route::put(
        '/orders/{id}/status',
        [OrderController::class, 'updateStatus']
);

        // -------------------------
        // Brands
        // -------------------------

        Route::post(
            '/brands',
            [BrandController::class, 'store']
        );

        Route::put(
            '/brands/{id}',
            [BrandController::class, 'update']
        );

        Route::delete(
            '/brands/{id}',
            [BrandController::class, 'destroy']
        );


        // -------------------------
        // Products
        // -------------------------

        Route::post(
            '/products',
            [ProductController::class, 'store']
        );

        Route::put(
            '/products/{id}',
            [ProductController::class, 'update']
        );

        Route::delete(
            '/products/{id}',
            [ProductController::class, 'destroy']
        );

    });


    // ==========================================
    // ADMIN ONLY
    // ==========================================

    Route::middleware('admin')->post(
        '/managers',
        [UserController::class, 'createManager']
    );

    Route::middleware('admin')->get(
        '/users/locations',
        [UserController::class, 'usersWithLocations']
    );

});