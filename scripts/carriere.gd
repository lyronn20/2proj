extends Node2D

var employes: Array = []

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)
		pnj.metier = "mineur"
		pnj.lieu_travail = self
