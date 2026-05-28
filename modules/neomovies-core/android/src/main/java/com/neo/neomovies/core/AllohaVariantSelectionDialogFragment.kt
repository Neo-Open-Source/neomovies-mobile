package com.neo.neomovies.core

import android.app.Dialog
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import androidx.fragment.app.activityViewModels

class AllohaVariantSelectionDialogFragment : DialogFragment() {

    private val viewModel: PlayerViewModel by activityViewModels()
    private var variantType: String = TYPE_AUDIO

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        variantType = arguments?.getString(ARG_TYPE) ?: TYPE_AUDIO
        
        return if (variantType == TYPE_AUDIO) {
            createAudioDialog()
        } else {
            createQualityDialog()
        }
    }
    
    private fun createAudioDialog(): Dialog {
        val variants = viewModel.getAllohaAudioVariants()
        if (variants.isEmpty()) {
            return AlertDialog.Builder(requireContext())
                .setTitle("Audio")
                .setMessage("No audio tracks available")
                .setNegativeButton(android.R.string.cancel, null)
                .create()
        }
        
        val labels = variants.map { it["title"] ?: "Unknown" }.toTypedArray()
        val currentIdx = variants.indexOfFirst { it["selected"] == "true" }.coerceAtLeast(0)
        
        return AlertDialog.Builder(requireContext())
            .setTitle("Audio Track")
            .setSingleChoiceItems(labels, currentIdx) { dialog, which ->
                dialog.dismiss()
                val index = variants[which]["index"]?.toIntOrNull() ?: which
                viewModel.selectAllohaAudioVariant(index)
            }
            .setNegativeButton(android.R.string.cancel, null)
            .create()
    }
    
    private fun createQualityDialog(): Dialog {
        val variants = viewModel.getAllohaQualityVariants()
        if (variants.isEmpty()) {
            return AlertDialog.Builder(requireContext())
                .setTitle("Quality")
                .setMessage("No quality options available")
                .setNegativeButton(android.R.string.cancel, null)
                .create()
        }
        
        val labels = variants.map { it["label"] ?: "Unknown" }.toTypedArray()
        val currentIdx = variants.indexOfFirst { it["selected"] == "true" }.coerceAtLeast(0)
        
        return AlertDialog.Builder(requireContext())
            .setTitle("Quality")
            .setSingleChoiceItems(labels, currentIdx) { dialog, which ->
                dialog.dismiss()
                val index = variants[which]["index"]?.toIntOrNull() ?: which
                if (index == -1) {
                    viewModel.selectAllohaAutoQuality()
                } else {
                    viewModel.selectAllohaQualityVariant(index)
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .create()
    }

    companion object {
        private const val ARG_TYPE = "type"
        const val TYPE_AUDIO = "audio"
        const val TYPE_QUALITY = "quality"

        fun newInstance(type: String): AllohaVariantSelectionDialogFragment {
            return AllohaVariantSelectionDialogFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_TYPE, type)
                }
            }
        }
    }
}
