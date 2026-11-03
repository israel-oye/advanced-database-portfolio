// Existing tenants from Postgres
//   Osun Alumni      → academic history (matric number, degree class)
//   Ife Medical Coop → medical credentials + cooperative financials
//   Lagos Tech       → startup / founder profile
//   None of these shapes belong together in a single SQL table.

use('kowojo');

db.member_profiles.drop();
db.member_profiles.createIndex({ member_id: 1 }, { unique: true });
print("\nCreated index on member_id...\n");

print('\n-- Collection cleared. Inserting seed data...\n');


// ─────────────────────────────────────────────────────────────
// TENANT 1: Osun State Alumni Association
// PostgreSQL tenant_id: a0000000-0000-0000-0000-000000000001
//
// Profile shape: the academic record a member held at the
// university. Relevant only to an alumni association
// ─────────────────────────────────────────────────────────────

db.member_profiles.insertMany([
    {
        // OSAA-0001 · Adebayo Okon (Chairman)
        member_id: "d0000000-0000-0000-0000-000000000001",
        tenant_id: "a0000000-0000-0000-0000-000000000001",
        membership_number: "OSAA-0001",
        tenant_type: "alumni_association",
        profile: {
            matric_number: "UNIOSUN/2008/ADM/011",
            graduation_year: 2012,
            faculty: "Management Sciences",
            department: "Business Administration",
            degree_class: "Second Class Upper"
        },
        metadata: {
            created_at: new Date("2024-01-10T09:00:00Z"),
            updated_at: new Date("2024-01-10T09:00:00Z"),
            verified: true
        }
    },
    {
        // OSAA-0002 · Funmilayo Ade (Financial Secretary)
        member_id: "d0000000-0000-0000-0000-000000000002",
        tenant_id: "a0000000-0000-0000-0000-000000000001",
        membership_number: "OSAA-0002",
        tenant_type: "alumni_association",
        profile: {
            matric_number: "UNIOSUN/2012/ACC/034",
            graduation_year: 2016,
            faculty: "Management Sciences",
            department: "Accounting",
            degree_class: "First Class"
        },
        metadata: {
            created_at: new Date("2024-01-15T09:00:00Z"),
            updated_at: new Date("2024-01-15T09:00:00Z"),
            verified: true
        }
    },
    {
        // OSAA-0003 · Chukwuemeka Eze (General Member)
        member_id: "d0000000-0000-0000-0000-000000000003",
        tenant_id: "a0000000-0000-0000-0000-000000000001",
        membership_number: "OSAA-0003",
        tenant_type: "alumni_association",
        profile: {
            matric_number: "UNIOSUN/2014/LAW/007",
            graduation_year: 2019,
            faculty: "Law",
            department: "Law",
            degree_class: "Second Class Upper"
        },
        metadata: {
            created_at: new Date("2024-02-01T09:00:00Z"),
            updated_at: new Date("2024-02-01T09:00:00Z"),
            verified: true
        }
    },
    {
        // OSAA-0004 · Ngozi Ibrahim (General Member)
        member_id: "d0000000-0000-0000-0000-000000000004",
        tenant_id: "a0000000-0000-0000-0000-000000000001",
        membership_number: "OSAA-0004",
        tenant_type: "alumni_association",
        profile: {
            matric_number: "UNIOSUN/2015/CSC/019",
            graduation_year: 2019,
            faculty: "Science",
            department: "Computer Science",
            degree_class: "Second Class Lower"
        },
        metadata: {
            created_at: new Date("2024-02-10T09:00:00Z"),
            updated_at: new Date("2024-02-10T09:00:00Z"),
            verified: false
        }
    }
]);

print('Osun Alumni — 4 profiles inserted.');


// ─────────────────────────────────────────────────────────────
// TENANT 2: Ife Medical Cooperative Society
// PostgreSQL tenant_id: a0000000-0000-0000-0000-000000000002
//
// Profile shape: HYBRID; all members are medical doctors
// who also belong to a savings cooperative. The profile must
// carry both their clinical credentials (specialization, MDCN
// licence) AND their cooperative standing (share_units, loan
// eligibility).
// ─────────────────────────────────────────────────────────────

db.member_profiles.insertMany([
    {
        // IFEM-0001 · Dr. Afolabi James (President)
        member_id: "d0000000-0000-0000-0000-000000000011",
        tenant_id: "a0000000-0000-0000-0000-000000000002",
        membership_number: "IFEM-0001",
        tenant_type: "medical_cooperative",
        profile: {
            specialization: "Cardiology",
            hospital_affiliation: "Obafemi Awolowo University Teaching Hospital",
            mdcn_number: "MDCN/2005/OYO/00871",
            licence_expiry_year: 2027,
            fellowship: true,
            fellowship_body: "West African College of Physicians",
            share_units: 200,
            loan_eligible: true,
            monthly_contribution: 10000
        },
        metadata: {
            created_at: new Date("2023-06-01T09:00:00Z"),
            updated_at: new Date("2023-06-01T09:00:00Z"),
            verified: true
        }
    },
    {
        // IFEM-0002 · Dr. Bukola Ojo (Treasurer)
        member_id: "d0000000-0000-0000-0000-000000000012",
        tenant_id: "a0000000-0000-0000-0000-000000000002",
        membership_number: "IFEM-0002",
        tenant_type: "medical_cooperative",
        profile: {
            specialization: "General Surgery",
            hospital_affiliation: "University College Hospital Ibadan",
            mdcn_number: "MDCN/2011/OYO/02234",
            licence_expiry_year: 2026,
            fellowship: false,
            share_units: 150,
            loan_eligible: true,
            monthly_contribution: 10000
        },
        metadata: {
            created_at: new Date("2023-06-05T09:00:00Z"),
            updated_at: new Date("2023-06-05T09:00:00Z"),
            verified: true
        }
    },
    {
        // IFEM-0003 · Dr. Emeka Nwosu (Fellow)
        member_id: "d0000000-0000-0000-0000-000000000013",
        tenant_id: "a0000000-0000-0000-0000-000000000002",
        membership_number: "IFEM-0003",
        tenant_type: "medical_cooperative",
        profile: {
            specialization: "Pediatrics",
            hospital_affiliation: "LAUTECH Teaching Hospital Osogbo",
            mdcn_number: "MDCN/2014/OSU/03301",
            licence_expiry_year: 2025,
            fellowship: false,
            share_units: 80,
            loan_eligible: false,
            monthly_contribution: 10000
        },
        metadata: {
            created_at: new Date("2023-07-01T09:00:00Z"),
            updated_at: new Date("2023-07-01T09:00:00Z"),
            verified: true
        }
    },
    {
        // IFEM-0004 · Dr. Halima Umar (Fellow)
        member_id: "d0000000-0000-0000-0000-000000000014",
        tenant_id: "a0000000-0000-0000-0000-000000000002",
        membership_number: "IFEM-0004",
        tenant_type: "medical_cooperative",
        profile: {
            specialization: "Obstetrics and Gynaecology",
            hospital_affiliation: "Federal Medical Centre Owo",
            mdcn_number: "MDCN/2016/OSU/04410",
            licence_expiry_year: 2028,
            fellowship: false,
            share_units: 60,
            loan_eligible: true,
            monthly_contribution: 10000
        },
        metadata: {
            created_at: new Date("2023-07-15T09:00:00Z"),
            updated_at: new Date("2023-07-15T09:00:00Z"),
            verified: false
        }
    }
]);

print('Ife Medical Coop — 4 profiles inserted.');


// ─────────────────────────────────────────────────────────────
// TENANT 3: Lagos Tech Founders Circle
// PostgreSQL tenant_id: a0000000-0000-0000-0000-000000000003
//
// Profile shape: founder / startup profile.
// ─────────────────────────────────────────────────────────────

db.member_profiles.insertMany([
    {
        // LTFC-0001 · Tobi Adegoke (Lead Organiser)
        member_id: "d0000000-0000-0000-0000-000000000021",
        tenant_id: "a0000000-0000-0000-0000-000000000003",
        membership_number: "LTFC-0001",
        tenant_type: "founders_circle",
        profile: {
            startup_name: "PaySprint",
            industry: "Fintech",
            founding_year: 2021,
            funding_stage: "seed",
            team_size: 12,
            primary_skill: "Product Management"
        },
        metadata: {
            created_at: new Date("2024-03-01T09:00:00Z"),
            updated_at: new Date("2024-03-01T09:00:00Z"),
            verified: true
        }
    },
    {
        // LTFC-0002 · Zainab Hussain (Founding Member)
        member_id: "d0000000-0000-0000-0000-000000000022",
        tenant_id: "a0000000-0000-0000-0000-000000000003",
        membership_number: "LTFC-0002",
        tenant_type: "founders_circle",
        profile: {
            startup_name: "SchoolBridge",
            industry: "EdTech",
            founding_year: 2022,
            funding_stage: "pre-seed",
            team_size: 4,
            primary_skill: "Curriculum Design",
            accelerator: "Ventures Platform"
        },
        metadata: {
            created_at: new Date("2024-03-05T09:00:00Z"),
            updated_at: new Date("2024-03-05T09:00:00Z"),
            verified: true
        }
    },
    {
        // LTFC-0003 · Femi Oladele (Founding Member)
        member_id: "d0000000-0000-0000-0000-000000000023",
        tenant_id: "a0000000-0000-0000-0000-000000000003",
        membership_number: "LTFC-0003",
        tenant_type: "founders_circle",
        profile: {
            startup_name: "ClinIQ",
            industry: "HealthTech",
            founding_year: 2023,
            funding_stage: "idea",
            team_size: 2,
            primary_skill: "Software Engineering"
        },
        metadata: {
            created_at: new Date("2024-03-10T09:00:00Z"),
            updated_at: new Date("2024-03-10T09:00:00Z"),
            verified: true
        }
    },
    {
        // LTFC-0004 · Blessing Okoro (Associate Member)
        member_id: "d0000000-0000-0000-0000-000000000024",
        tenant_id: "a0000000-0000-0000-0000-000000000003",
        membership_number: "LTFC-0004",
        tenant_type: "founders_circle",
        profile: {
            startup_name: "HarvestLink",
            industry: "AgriTech",
            founding_year: 2022,
            funding_stage: "pre-seed",
            team_size: 6,
            primary_skill: "Business Development",
            accelerator: "GreenHouse Capital"
        },
        metadata: {
            created_at: new Date("2024-04-01T09:00:00Z"),
            updated_at: new Date("2024-04-01T09:00:00Z"),
            verified: false
        }
    }
]);

print('Lagos Tech Founders — 4 profiles inserted.');
