-- CreateTable
CREATE TABLE "child_curriculum_notes" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "note_text" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'manual',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "child_curriculum_notes_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "child_curriculum_notes" ADD CONSTRAINT "child_curriculum_notes_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
