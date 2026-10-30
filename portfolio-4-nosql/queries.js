// QUERY 1: Find all loan-eligible members in the Ife Medical Coop
//
// EXPECTED RESULT: 3 documents (IFEM-0001, IFEM-0002, IFEM-0004)
//   IFEM-0003 (Dr. Emeka Nwosu) is excluded — loan_eligible: false

print('\n── Query 1: Loan-eligible Ife Medical Coop members ──');

db.member_profiles.find(
  {
    tenant_id: "a0000000-0000-0000-0000-000000000002",
    "profile.loan_eligible": true
  },
  {
    _id: 0,
    membership_number: 1,
    "profile.specialization": 1,
    "profile.share_units": 1,
    "profile.loan_eligible": 1
  }
);



// QUERY 2: Find practitioners whose MDCN licence expires by 2026
//
//
// EXPECTED RESULT: 2 documents
//   IFEM-0002 (Dr. Bukola Ojo)  — expires 2026
//   IFEM-0003 (Dr. Emeka Nwosu) — expires 2025

print('\n── Query 2: Practitioners with licences expiring by 2026 ──');

db.member_profiles.find(
  {
    tenant_type: "medical_cooperative",
    "profile.licence_expiry_year": { $lte: 2026 }
  },
  {
    _id: 0,
    membership_number: 1,
    "profile.specialization": 1,
    "profile.mdcn_number": 1,
    "profile.licence_expiry_year": 1
  }
);


// QUERY 3: Aggregation: member count and verification status
//          grouped by tenant type
//
//
// EXPECTED RESULT: 3 documents (one per tenant type)
//   Each shows total_members: 4 and unverified_count: 1

print('\n── Query 3: Member count and unverified profiles by tenant type ──');

db.member_profiles.aggregate([
  {
    $group: {
      _id: "$tenant_type",
      total_members: { $sum: 1 },
      unverified_count: {
        $sum: {
          $cond: [{ $eq: ["$metadata.verified", false] }, 1, 0]
        }
      }
    }
  },
  {
    $project: {
      _id: 0,
      tenant_type: "$_id",
      total_members: 1,
      unverified_count: 1
    }
  },
  { $sort: { total_members: -1 } }
]);

print('\n── All queries complete. ──\n');