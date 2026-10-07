<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserLocation extends Model
{
    protected $fillable = [
        'user_id',
        'latitude',
        'longitude',
        'location_enabled',
        'last_updated',
        'address',
    ];

    protected $casts = [
        'location_enabled' => 'boolean',
        'latitude' => 'float',
        'longitude' => 'float',
        'last_updated' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}