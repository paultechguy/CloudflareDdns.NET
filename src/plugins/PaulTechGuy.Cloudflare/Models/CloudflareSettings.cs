﻿// <copyright file="CloudflareSettings.cs" company="PaulTechGuy"
// Copyright (c) Paul Carver. All rights reserved.
// </copyright>"

namespace PaulTechGuy.Cloudflare.Models;

/// <summary>
/// A class representing the appSettings configuration section for the Cloudflare
/// <see cref="DdnsUpdatePlugin"/>.
/// </summary>
public class CloudflareSettings
{
   /// <summary>
   /// The <see cref="CloudflareDefaultDomain"/> object properties to use when
   /// the Domains object properties do not contain a value.
   /// </summary>
   public CloudflareDefaultDomain DefaultDomain { get; set; }

   /// <summary>
   /// A collection of <see cref="CloudflareDomain"/> object configurations.
   /// </summary>
   public CloudflareDomain[] Domains { get; set; }

   /// <summary>
   /// Creates a new instance of the <see cref="CloudflareSettings"/> class.
   /// </summary>
   public CloudflareSettings()
   {
      this.DefaultDomain = new CloudflareDefaultDomain();
      this.Domains = [];
   }
}
